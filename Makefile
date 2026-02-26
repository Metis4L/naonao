.PHONY: preflight shadow-monitoring validate-json validate-work-order-schema advisor-plan p0-all p15-all execute-work-order queue-progress queue-mark-inflight auto-advance-once

WORK_ORDER ?= projects/naonao-content-ops/handovers/work-order-shadow-monitoring.json
MANIFEST ?= projects/naonao-content-ops/handovers/root-manifest.json
PHASE ?= phase_1_shadow_soft
RUN_MODE ?= test
GATE_REPORT ?= projects/naonao-content-ops/reports/hard-validator-gate.latest.json

preflight:
	python3 projects/naonao-content-ops/tools/preflight-root-check.py \
		--manifest $(MANIFEST) \
		--work-order $(WORK_ORDER) \
		--phase $(PHASE) \
		--emit projects/naonao-content-ops/reports/preflight.latest.json

shadow-monitoring:
	python3 projects/naonao-content-ops/tools/run-shadow-monitoring.py

validate-json:
	python3 projects/naonao-content-ops/tools/validate-json-batch.py

validate-work-order-schema:
	python3 projects/naonao-content-ops/tools/validate-work-order-schema.py \
		--work-order "$(WORK_ORDER)" \
		--schema projects/naonao-content-ops/contracts/work-order.schema.json \
		--out projects/naonao-content-ops/reports/work-order-schema-validation.latest.json \
		--gate "$(GATE_REPORT)"

advisor-plan:
	python3 projects/naonao-content-ops/tools/advisor-compile-plan.py \
		--brief projects/naonao-content-ops/handovers/brief.template.md

execute-work-order:
	bash projects/naonao-content-ops/tools/run-selected-work-order.sh "$(WORK_ORDER)" "$(RUN_MODE)"

queue-progress:
	python3 projects/naonao-content-ops/tools/queue-progress.py --stage post --gate "$(GATE_REPORT)"

queue-mark-inflight:
	python3 projects/naonao-content-ops/tools/queue-progress.py --stage pre --gate "$(GATE_REPORT)"

p0-all: preflight validate-json shadow-monitoring
	@echo "P0 pipeline done (test/shadow mode)."

p15-all:
	@python3 projects/naonao-content-ops/tools/advisor-compile-plan.py \
		--brief projects/naonao-content-ops/handovers/brief.template.md
	@decision=$$(python3 -c "import json;print(json.load(open('projects/naonao-content-ops/reports/advisory-decision.latest.json',encoding='utf-8')).get('decision','auto_proceed'))"); \
	if [ "$$decision" = "idle" ]; then \
		echo "P1.5 idle (queue empty/inactive)."; \
		exit 0; \
	fi; \
	if [ "$$decision" = "needs_human_approval" ]; then \
		echo "P1.5 paused: approval required."; \
		exit 0; \
	fi; \
	wo=$$(python3 -c "import json;print(json.load(open('projects/naonao-content-ops/reports/execution-plan.latest.json',encoding='utf-8')).get('selected_work_order','projects/naonao-content-ops/handovers/work-order-shadow-monitoring.json'))"); \
	run_mode=$$(python3 -c "import json;print(json.load(open('projects/naonao-content-ops/reports/execution-plan.latest.json',encoding='utf-8')).get('mode','test'))"); \
	$(MAKE) preflight WORK_ORDER="$$wo" && \
	$(MAKE) validate-json && \
	$(MAKE) queue-mark-inflight GATE_REPORT="$(GATE_REPORT)" && \
	if ! $(MAKE) validate-work-order-schema WORK_ORDER="$$wo" GATE_REPORT="$(GATE_REPORT)"; then \
		echo "P1.5 hard-fail: selected work-order schema invalid."; \
		$(MAKE) queue-progress GATE_REPORT="$(GATE_REPORT)"; \
		exit 2; \
	fi; \
	$(MAKE) execute-work-order WORK_ORDER="$$wo" RUN_MODE="$$run_mode" && \
	$(MAKE) queue-progress GATE_REPORT="$(GATE_REPORT)" && \
	$(MAKE) shadow-monitoring && \
	echo "P1.5 pipeline done (advisor + execute + p0 checks)."

auto-advance-once:
	@AUTO_ADVANCE=1 $(MAKE) p15-all; rc=$$?; \
	python3 -c "import json; from pathlib import Path; adv_p=Path('projects/naonao-content-ops/reports/advisory-decision.latest.json'); plan_p=Path('projects/naonao-content-ops/reports/execution-plan.latest.json'); adv=json.load(open(adv_p,encoding='utf-8')) if adv_p.exists() else {}; plan=json.load(open(plan_p,encoding='utf-8')) if plan_p.exists() else {}; summary={'decision': adv.get('decision'), 'selected_work_order': plan.get('selected_work_order') or adv.get('selected_work_order') or ((adv.get('context') or {}).get('selected_wo') or {}).get('path'), 'auto_selected_wo_id': adv.get('auto_selected_wo_id') or ((adv.get('context') or {}).get('selected_wo') or {}).get('wo_id')}; out=Path('projects/naonao-content-ops/reports/auto-advance-once.latest.json'); out.parent.mkdir(parents=True,exist_ok=True); out.write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8'); print(json.dumps(summary,ensure_ascii=False)); print('auto-advance summary written: %s' % out)"; \
	exit $$rc