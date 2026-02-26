.PHONY: preflight shadow-monitoring validate-json advisor-plan p0-all p15-all execute-work-order queue-progress queue-mark-inflight

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
	$(MAKE) execute-work-order WORK_ORDER="$$wo" RUN_MODE="$$run_mode" && \
	$(MAKE) queue-progress GATE_REPORT="$(GATE_REPORT)" && \
	$(MAKE) shadow-monitoring && \
	echo "P1.5 pipeline done (advisor + execute + p0 checks)."