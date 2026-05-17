PREFIX = /usr/local

install:
	install -Dm755 aur-taw $(DESTDIR)$(PREFIX)/bin/aur-taw
	install -Dm644 aur-taw-completion.bash $(DESTDIR)/usr/share/bash-completion/completions/aur-taw

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/aur-taw
	rm -f $(DESTDIR)/usr/share/bash-completion/completions/aur-taw

.PHONY: install uninstall
