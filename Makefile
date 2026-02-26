.PHONY: preflight shadow-monitoring validate-json advisor-plan p0-all p15-all

WORK_ORDER ?= projects/naonao-content-ops/handovers/work-order-shadow-monitoring.json
MANIFEST ?= projects/naonao-content-ops/handovers/root-manifest.json
PHASE ?= phase_1_shadow_soft

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
	$(MAKE) p0-all WORK_ORDER="$$wo"; \
	echo "P1.5 pipeline done (advisor + p0)."