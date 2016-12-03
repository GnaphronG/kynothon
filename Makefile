PREFIX := swarm
RUNNING_MACHINES = $(shell docker-machine ls --filter state=Running -q | grep $(PREFIX)-)
STOPPED_MACHINES = $(shell docker-machine ls --filter state=Stopped -q | grep $(PREFIX)-)
SWARM_MACHINES = $(RUNNING_MACHINES) $(STOPPED_MACHINES)


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

define machine_name =
$(subst $1,$(PREFIX),$@)
endef

define stopped_machine =
$(call machine_name,stop)
endef

define cleaned_machine =
$(call machine_name,clean)
endef

define rm_machine =
docker-machine rm -f -y $(shell docker-machine ls -q | grep $(call cleaned_machine))
endef

define stop_machine =
docker-machine stop $(shell docker-machine ls -q | grep $(call stopped_machine)) 
endef


help:
	@echo 'token		Regenerate a swarm token'
	@echo 'master		Spawn a swarm master'
	@echo 'agent-{ID}	Spawn a swarm agent and add it to the cluster'
	@echo 'all		Spawn a swarm cluster (i.e. all of the above)'
	@echo 'show_machines	Show machines of the cluster'
	@echo 'swarm_info	Show info about the swarm cluser'
	@echo 'swarm_env	Swarm environmnent configuration'
	@echo ''
	@echo 'stop			Stop the cluster'	
	@echo 'stop-master	Stop the swarm master'
	@echo 'stop-agent	Stop the swarm agents'
	@echo 'stop-agent-{ID}Stop the swarm agent {ID}'
	@echo ''
	@echo 'clean		Remove the cluster'	
	@echo 'clean-token	Remove the swarm token'
	@echo 'clean-master	Remove the swarm master'
	@echo 'clean-agent	Remove the swarm agents'
	@echo 'clean-agent-{ID}Remove the swarm agent {ID}'


all: token master agent-00 agent-01 swarm-env

swarm_env:
	@echo 'Swarm cluster has been created and is now active machines.'
	@echo 'To point your Docker client at it, run this in your shell:'
	@echo 'eval $$(docker-machine env --swarm $(PREFIX)-master)'

swarm_info:
	$(call machine_env, --swarm $(PREFIX)-master)
	docker info
	

token: 
ifeq (, $(findstring $(PREFIX)-local, $(shell docker-machine ls -q)))
	@docker-machine create -d virtualbox $(PREFIX)-local	
endif
	@echo 'load env'
	$(call machine_env, $(PREFIX)-local)
	@echo 'get token'
	@2>/dev/null  docker -l error run --rm swarm create | tee token

master: $(PREFIX)-master swarm-env

agent-%: master $(PREFIX)-agent-%;

show_machines:
	@docker-machine ls

$(PREFIX)-%: token
	$(if $(findstring $(shell cat token), $(shell docker-machine inspect --format '{{.Driver.SwarmDiscovery}}' $@)), \
		@echo -n , $(call swarm_machine))
	$(if $(findstring Stopped, $(shell docker-machine status $@)), \
		@docker-machine start $@)

clean-token:
	@rm -f token
	@docker-machine rm -f -y local 2>/dev/null

clean-master:
	$(if $(findstring $(PREFIX)-master, $(SWARM_MACHINES)), $(call rm_machine))

clean-agent-%:
	$(if $(findstring $(call cleaned_machine), $(SWARM_MACHINES)), $(call rm_machine))

clean-agent:
	$(if $(findstring $(call cleaned_machine), $(SWARM_MACHINES)), $(call rm_machine))
	
stop-master stop-local:
	$(if $(findstring $(PREFIX)-master, $(RUNNING_MACHINES)), $(call stop_machine))

stop-agent-%:
	$(if $(findstring $(call stopped_machine), $(RUNNING_MACHINES)), $(call stop_machine))

stop-agent:
	$(if $(findstring $(call stopped_machine), $(RUNNING_MACHINES)), $(call stop_machine))

stop: stop-master stop-agent stop-local

clean: clean-token clean-master clean-agent

.PHONY: all clean clean-token clean-master clean-agents swarm-env help
