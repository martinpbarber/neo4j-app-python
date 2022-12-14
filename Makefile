PWD := $(shell pwd)

VENV := .venv
ACTIVATE := $(VENV)/bin/activate
ACTIVATE_VENV := . $(ACTIVATE)

CONTAINER_IMAGE := neo4j:4.4.11-community
CONTAINER_NAME := neo4j-app-python
USERNAME := neo4j
PASSWORD := password
CONTAINER_AUTH := $(USERNAME)/$(PASSWORD)
CONTAINER_DIR := $(PWD)/neo4j
# See https://github.com/neo4j-graph-examples/recommendations
RECOMMENDATIONS_DUMP_FILE := recommendations-43.dump
# User email constraint 
EMAIL_CONSTRAINT := CREATE CONSTRAINT UserEmailUnique IF NOT EXISTS FOR (u:User) REQUIRE u.email IS UNIQUE
# Some names have leading whitespace which breaks tests/14_person_list__test.py
TRIM_NAMES := MATCH (p:Person) SET p.name = trim(p.name)


.PHONY: test
test: venv
	$(ACTIVATE_VENV) && pytest -v -s -Wignore \
	tests/01_connect_to_neo4j__test.py \
	tests/02_movie_list__test.py \
	tests/03_registering_a_user__test.py \
	tests/04_handle_constraint_errors__test.py \
	tests/05_authentication__test.py \
	tests/06_rating_movies__test.py \
	tests/07_favorites_list__test.py \
	tests/08_favorite_flag__test.py \
	tests/09_genre_list__test.py \
	tests/10_genre_details__test.py \
	tests/11_movie_lists__test.py \
	tests/12_movie_details__test.py \
	tests/13_listing_ratings__test.py \
	tests/14_person_list__test.py \
	tests/15_person_profile__test.py

.PHONY: run
run: venv
	$(ACTIVATE_VENV) && flask run

# Use a local Neo4j database: Load recommendations
.PHONY: db-init
db-init: db-clean
	docker run -it \
	-v $(CONTAINER_DIR)/data:/data \
	-v $(CONTAINER_DIR)/import:/import \
	--name $(CONTAINER_NAME) \
	--rm $(CONTAINER_IMAGE) \
	neo4j-admin load --from /import/$(RECOMMENDATIONS_DUMP_FILE)

.PHONY: db-start
db-start:
	docker run \
	-p7474:7474 -p7687:7687 \
	-e NEO4J_AUTH=$(CONTAINER_AUTH) \
	-v $(CONTAINER_DIR)/data:/data \
	-v $(CONTAINER_DIR)/logs:/logs \
	-v $(CONTAINER_DIR)/import:/import \
	--name $(CONTAINER_NAME) \
	-d $(CONTAINER_IMAGE)

	@printf "Waiting for database "
	@until curl -s -f -o /dev/null "http://localhost:7474"; do printf "."; sleep 1; done
	@printf " Ready\n"

	@echo "Adding user email constraint"
	@echo '$(EMAIL_CONSTRAINT)' | docker exec -i $(CONTAINER_NAME) cypher-shell -u $(USERNAME) -p $(PASSWORD)

	@echo "Trim names"
	@echo '$(TRIM_NAMES)' | docker exec -i $(CONTAINER_NAME) cypher-shell -u $(USERNAME) -p $(PASSWORD)

.PHONY: db-stop
db-stop:
	-docker stop $(CONTAINER_NAME)

.PHONY: db-remove
db-remove: db-stop
	-docker rm $(CONTAINER_NAME) 

.PHONY: db-clean
db-clean: db-remove
	rm -rf $(CONTAINER_DIR)/data
	rm -rf $(CONTAINER_DIR)/logs

.PHONY: venv
venv: $(ACTIVATE)
$(ACTIVATE): requirements.txt
	python3 -m venv $(VENV)
	$(ACTIVATE_VENV) && pip install -r requirements.txt

.PHONY: versions
versions: venv
	$(ACTIVATE_VENV) && pip list

.PHONY: outdated
outdated: venv
	$(ACTIVATE_VENV) && pip list --outdated

.PHONY: clean
clean:
	rm -rf $(VENV)
	find . -name '__pycache__' -exec rm -rf {} +
