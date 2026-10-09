.PHONY: bench update-bench

init:
	poetry install && poetry shell


include env/app.env
export

up:
	docker-compose -f docker-compose.yaml --env-file ./env/app.env up -d
logs:
	docker-compose -f docker-compose.yaml logs -f liquibase
down:
	docker-compose -f docker-compose.yaml down
update:
	docker-compose -f docker-compose.yaml run --rm liquibase update
update-common:
	docker-compose -f docker-compose.yaml run --rm \
		-e LIQUIBASE_COMMAND_CONTEXTS=common \
		liquibase update
update-bench:
	docker-compose -f docker-compose.yaml run --rm \
		-e LIQUIBASE_COMMAND_CONTEXTS=common,bench \
		liquibase update

bench:
	@if [ -z "$(TIER)" ]; then \
		echo "Error: TIER is required. Usage: make bench TIER=mid_5y"; \
		exit 1; \
	fi
	cd python/json_parser && python run_transform.py $(TIER)
	$(MAKE) update-bench

bench-etl:
	@if [ -z "$(ARGS)" ]; then \
		echo 'Error: ARGS is required. Usage: make bench-etl ARGS="full mid_5y --reps 5"'; \
		exit 1; \
	fi
	$(MAKE) clear up update-common
	python bench/run_etl_benchmark.py $(ARGS)

bench-queries:
	@if [ -z "$(TIER)" ]; then \
		echo "Error: TIER is required. Usage: make bench-queries TIER=mid_10y"; \
		exit 1; \
	fi
	$(MAKE) clear up update-common
	cd python/json_parser && python run_transform.py $(TIER)
	python bench/run_query_benchmarks.py --tier $(TIER) --load --repetitions 5

bench-evolution:
	@if [ -z "$(TIER)" ]; then \
		echo "Error: TIER is required. Usage: make bench-evolution TIER=mid_10y"; \
		exit 1; \
	fi
	$(MAKE) clear up update-common
	python bench/run_evolution_test.py $(TIER) --reps 5
status:
	docker-compose -f docker-compose.yaml run --rm liquibase status --verbose
tag:
	@if [ -z "$(TAG)" ]; then \
		echo "Error: TAG is required. Usage: make tag TAG=v0.1-step1-base-structure"; \
		exit 1; \
	fi
	docker-compose -f docker-compose.yaml run --rm liquibase tag $(TAG)
rollback-tag:
	@if [ -z "$(TAG)" ]; then \
		echo "Error: TAG is required. Usage: make rollback-tag TAG=v0.1-step1-base-structure"; \
		exit 1; \
	fi
	docker-compose -f docker-compose.yaml run --rm liquibase rollback $(TAG)
clear-checksums:
	docker-compose -f docker-compose.yaml run --rm liquibase clear-checksums
clear:
	docker-compose -f docker-compose.yaml down -v