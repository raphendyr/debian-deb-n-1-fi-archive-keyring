ACTIVE-LIST := $(wildcard active-keys/*.asc)
REMOVED-LIST := $(wildcard removed-keys/*.asc)
SUPPORTING-LIST := $(wildcard supporting-keys/*.asc)

KEYRINGS := \
	$(if $(ACTIVE-LIST),keyrings/deb.n-1.fi-archive-keyring.gpg,) \
	$(if $(REMOVED-LIST),keyrings/deb.n-1.fi-archive-removed-keys.gpgm,)

GPG_HOME := build-gpg-home
GPG_OPTIONS := --no-options --no-default-keyring --no-auto-check-trustdb --trustdb-name ./trustdb.gpg

PACKAGE_NAME := $(shell dpkg-parsechangelog -ldebian/changelog | grep '^Source: ' | cut -f2 -d' ')
PACKAGE_VERSION := $(shell dpkg-parsechangelog -ldebian/changelog | grep '^Version: ' | cut -f2 -d' ')


$(GPG_HOME)/pubring.kbx: $(SUPPORTING-LIST)
	mkdir -p $(GPG_HOME)
	gpg --no-options --homedir $(GPG_HOME) --import $^

keyrings/deb.n-1.fi-archive-keyring.gpg: $(ACTIVE-LIST)
keyrings/deb.n-1.fi-archive-removed-keys.gpg: $(REMOVED-LIST)

keyrings/%.gpg:
	gpg ${GPG_OPTIONS} --keyring $@ --import $^


verify-results: $(KEYRINGS) | $(GPG_HOME)/pubring.kbx
	for keyring in $`; do \
		gpg --no-options --homedir $(GPG_HOME) \
			--keyring $$keyring \
			--check-signatures ; \
	done
	# TODO: check for missing keys


clean:
	rm -f $(KEYRINGS) keyrings/*.cache
	rm -rf $(GPG_HOME) trustdb.gpg

build: $(KEYRINGS) verify-results

install: $(KEYRINGS) verify-results
	install -d $(DESTDIR)/usr/share/keyrings/
	cp $(KEYRINGS) $(DESTDIR)/usr/share/keyrings/


build-release:
	debuild -i -I

upload: build-release
	@echo Uploading changes to the remote, see ~/.dupload.conf
	for changes in ../$(PACKAGE_NAME)_$(PACKAGE_VERSION)_*.changes; do \
		dupload -t deb.n-1.fi $$changes ; \
	done


.PHONY: verify-results clean build install build-release upload
