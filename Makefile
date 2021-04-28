PATH := ./node_modules/.bin:$(PATH)

MONGO_RUNNING = mongo --quiet $(ANNO_MONGODB_NAME) ping.js
MONGODUMP = mongodump --db $(ANNO_MONGODB_NAME)
MONGORESTORE = mongorestore

ANNO_MONGODB_NAME = 'anno'
BACKUP_PATH = /usr/local/AnnotationService/backup

BACKUP = $(shell date +"anno.%Y-%m-%d_%H-%M-%S")
MONGODB_BACKUP = $(BACKUP_PATH)/$(BACKUP)

DEPS = node_modules/@kba/anno-errors        \
       node_modules/@kba/anno-store-file    \
       node_modules/@kba/anno-util-loaders  \
       node_modules/@kba/anno-store-mongodb \
       node_modules/@kba/anno-plugins

help:
	@echo "Targets:"
	@echo ""
	@echo "  bootstrap    Update anno-common after adding/removing deps"
	@echo "  install      Run before setting up the server"
	@echo "  symlink      'npm link' the necessary packages"
	@echo "  start        Start the server"
	@echo "  backup       Create a backup"
	@echo "  restore      Restore the backup given as MONGODB_BACKUP"
	@echo "  prune        Remove old backups, older than seven days"
	@echo ""
	@echo "Variables"
	@echo ""
	@echo "  MONGODB_BACKUP"
	@echo "  ANNO_MONGODB_NAME    MongoDB database where annotations are stored"
	@echo "  BACKUP_PATH          Folder to contain backups"
	@echo "  BACKUP               Basename of the backup to create/restore. Defaults to timestamp ($(BACKUP))"

bootstrap:
	[ -d anno-common ] || ln --symbolic --no-target-directory -- anno-common.known-good anno-common
	[ -f anno-common/package.json ] || git submodule update --init --recursive
	( cd anno-common && npm install && npm run bootstrap ) 2>&1 | ( ts || cat ) | tee -- make.bootstrap.log

.PHONY: $(DEPS) symlink bootstrap install start
symlink: $(DEPS)
$(DEPS): node_modules/@kba/%: anno-common/%
	cd "$<"
	npm link
	npm link "@kba/$*"

install: bootstrap
	npm install

start:
	pm2 kill
	pm2 --no-daemon start pm2.prod.yml

.PHONY: backup
backup:
	@echo "# Backing up $(MONGODB_BACKUP)"
	$(MONGODUMP) --out $(MONGODB_BACKUP)
	cd backup && tar cf $(MONGODB_BACKUP).tar $(BACKUP)
	gzip $(MONGODB_BACKUP).tar
	rm -rf $(MONGODB_BACKUP)

prune:
	@echo "# Pruning old backups"
	@find $(BACKUP_PATH) -mindepth 1 -maxdepth 1 -name "anno.*" -mtime +7 -exec rm -rvf {} \;

restore:
	@echo "# Restoring $(MONGODB_BACKUP)"
	@if [ ! -e "$(MONGODB_BACKUP)" ];then \
		if [ -e "$(MONGODB_BACKUP).tar.gz" ];then \
			cd backup && tar xvf "$(MONGODB_BACKUP).tar.gz"; \
		fi; \
		if [ ! -e "$(MONGODB_BACKUP)" ];then \
			echo "No such folder $(MONGODB_BACKUP)\nUsage: make $@ BACKUP=<backup-timestamp>" ; \
			exit 2; \
		fi; \
	fi
	$(MONGORESTORE) $(MONGODB_BACKUP)
