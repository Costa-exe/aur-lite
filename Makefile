VERSION ?= v1.2.0-dev
PREFIX = /usr/local
LIB_DIR = $(PREFIX)/share/aur-taw/lib

install:
	install -Dm755 aur-taw $(DESTDIR)$(PREFIX)/bin/aur-taw
	install -Dm644 aur-taw-completion.bash $(DESTDIR)/usr/share/bash-completion/completions/aur-taw
	
	install -d $(DESTDIR)$(LIB_DIR)
	install -Dm644 lib/*.bash $(DESTDIR)$(LIB_DIR)/
	
	sed -i 's/^VERSION=.*/VERSION="$(VERSION)"/' $(DESTDIR)$(PREFIX)/bin/aur-taw
	sed -i 's|^SYSTEM_LIB_DIR=.*|SYSTEM_LIB_DIR="$(LIB_DIR)"|' $(DESTDIR)$(PREFIX)/bin/aur-taw

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/aur-taw
	rm -f $(DESTDIR)/usr/share/bash-completion/completions/aur-taw
	rm -rf $(DESTDIR)$(LIB_DIR)

.PHONY: install uninstall