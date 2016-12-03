PREFIX := swarm
SWARM_MACHINES = $(shell docker-machine ls -q | grep $(PREFIX)-)

define machine_env =
$(foreach env, $(shell docker-machine env $1 | sed -e '/^#/d' -e 's/export *//' -e 's/=/:=/' -e 's/"//g'), $(eval $(env)))
endef 

define swarm_machine =
docker-machine rm -f -y $@
docker-machine create \
	-d virtualbox \
	--$(if $(findstring master, $@),swarm-master,swarm) \
	--swarm-discovery token://$(shell cat token) \
	$@
endef

define cleaned_machine =
$(subst clean,$(PREFIX),$@)
endef

define rm_machine =
docker-machine rm -f -y $(shell docker-machine ls -q | grep $(call cleaned_machine))
endef

all: token master agent-00 agent-01 swarm-env

swarm-env:
	@echo 'Swarm cluster has been created and is now active machines.'
	@echo 'To point your Docker client at it, run this in your shell:'
	@echo 'eval $$(docker-machine env --swarm $(PREFIX)-master)'

swarm-info:
	$(call machine_env, --swarm $(PREFIX)-master)
	docker info
	

token: 
ifeq (, $(findstring local, $(shell docker-machine ls -q)))
	@docker-machine create -d virtualbox local	
endif
	$(call machine_env, local)
	@2>/dev/null  docker -l error run --rm swarm create | tee token

master: $(PREFIX)-master swarm-env

agent-%: $(PREFIX)-agent-%;

show_machines:
	@docker-machine ls

$(PREFIX)-%: token
	$(if $(findstring $(shell cat token), $(shell docker-machine inspect --format '{{.Driver.SwarmDiscovery}}' $@)), \
		@echo -n , $(call swarm_machine))
clean-token:
	@rm -f token
	@docker-machine rm -f -y local 2>/dev/null

clean-master:
	$(if $(findstring $(PREFIX)-master, $(SWARM_MACHINES)), $(call rm_machine))

clean-agent-%:
	$(if $(findstring $(call cleaned_machine), $(SWARM_MACHINES)), $(call rm_machine))

clean-agent:
	$(if $(findstring $(call cleaned_machine), $(SWARM_MACHINES)), $(call rm_machine))
	
clean: clean-token clean-master clean-agent

.PHONY: all clean clean-token clean-master clean-agents swarm-env
