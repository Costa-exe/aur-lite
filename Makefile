PREFIX = /usr/local

install:
	install -Dm755 aur-lite $(DESTDIR)$(PREFIX)/bin/aur-lite
	install -Dm644 aur-lite-completion.bash $(DESTDIR)/usr/share/bash-completion/completions/aur-lite

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/aur-lite
	rm -f $(DESTDIR)/usr/share/bash-completion/completions/aur-lite

.PHONY: install uninstall
