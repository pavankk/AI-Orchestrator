.PHONY: run status start stop restart health dashboard install clean

run: start

start:
	orch daemon-start

stop:
	orch daemon-stop

status:
	orch status

health:
	orch health

dashboard:
	orch dashboard

install:
	bash install.sh

clean:
	rm -f run/*.pid run/*.heartbeat run/daemon.lock
