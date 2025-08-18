.PHONY: help check_clean bookworm kali jammy noble bennu docker-hello-world ntp clean

.ONESHELL: # for heredoc and exit

PHENIX=docker exec phenix phenix
PHENIX_IMAGE_BUILD=$(PHENIX) image build -o . -c -x
CHECK_IMAGE=if $(PHENIX) cfg list | grep Image | awk '{print $$6}' | grep "^$(@)$$" >/dev/null; then echo "\n\tphenix image already exists: '$(@)' - run 'phenix image delete $(@)' first\n"; exit; fi
INJECT_MINICCC=if test -f $(CURDIR)/$(@).qc2; then $(PHENIX) image inject-miniexe $(CURDIR)/miniccc $(CURDIR)/$(@).qc2; echo "----- Injected miniccc into $(@).qc2 -----"; fi
COMPRESS=-c

# Show this help
help:
	@cat $(MAKEFILE_LIST) | docker run --rm -i xanders/make-help

check_clean:
	@echo -n "Are you sure you want to delete [*.log *.qc2 *.tar *.vmdb]? [y/N] " && read ans && [ $${ans:-N} = y ]

##
## --------------------------------------- Vanilla image builds ---------------------------------------
##

# Build bookworm.qc2	-- Debian Bookworm, GUI
bookworm:
	@$(CHECK_IMAGE)
	@$(PHENIX) image create -r bookworm -v mingui $(COMPRESS) $(@)
	@$(PHENIX_IMAGE_BUILD) $(@)
	@$(INJECT_MINICCC)

# Build kali.qc2		-- Kali, GUI
kali:
	@$(CHECK_IMAGE)
	@$(PHENIX) image create -P kali-tools-top10 -r kali-rolling -v mingui $(COMPRESS) $(@)
	@$(PHENIX_IMAGE_BUILD) $(@)
	@$(INJECT_MINICCC)

# Build jammy.qc2		-- Ubuntu Jammy, GUI
jammy:
	@$(CHECK_IMAGE)
	@$(PHENIX) image create -v mingui $(COMPRESS) $(@)
	@$(PHENIX_IMAGE_BUILD) $(@)
	@$(INJECT_MINICCC)

# Build noble.qc2		-- Ubuntu Noble, GUI
noble:
	@$(CHECK_IMAGE)
	@$(PHENIX) image create -r noble -v mingui $(COMPRESS) $(@)
	@$(PHENIX_IMAGE_BUILD) $(@)
	@$(INJECT_MINICCC)

##
## ------------------------------------- Experiment image builds --------------------------------------
##

# Build bennu.qc2			-- Ubuntu Jammy, bennu, brash
bennu:
	@$(CHECK_IMAGE)
	@$(PHENIX) image create -O $(CURDIR)/overlays/bennu,$(CURDIR)/overlays/brash -T $(CURDIR)/scripts/atomic/aptly.sh,$(CURDIR)/scripts/bennu.sh $(COMPRESS) $(@)
	@$(PHENIX_IMAGE_BUILD) $(@)
	@$(INJECT_MINICCC)

# Build docker-hello-world.qc2	-- Ubuntu Jammy, Docker hello-world
docker-hello-world:
	@$(CHECK_IMAGE)
	@$(PHENIX) image create -T $(CURDIR)/scripts/atomic/docker.sh $(COMPRESS) $(@)
	@$(PHENIX_IMAGE_BUILD) $(@)

# Build ntp.qc2			-- Ubuntu Jammy, ntpd
ntp:
	@$(CHECK_IMAGE)
	@$(PHENIX) image create -P ntp $(COMPRESS) $(@)
	@$(PHENIX_IMAGE_BUILD) $(@)
	@$(INJECT_MINICCC)

# Build vyos.qc2			-- VyOS 1.5
vyos:
	@cd $(CURDIR)/scripts/vyos/
	@./build-vyos.sh -m $(CURDIR)/miniccc
	@mv vyos.qc2 $(CURDIR)

##
## ------------------------------------------ Administration ------------------------------------------
##

# Delete files [*.log *.qc2 *.tar *.vmdb]
clean: check_clean
	@echo "Deleting *.log *.qc2 *.tar *.vmdb..."
	rm -f *.log *.qc2 *.tar *.vmdb
