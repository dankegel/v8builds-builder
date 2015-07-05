# Example of how to use build.sh to build a particular version of v8
# This Makefile is suitable for use in a default debian rules file

# The directory we create isn't quite system-like, so put it off to the side a bit
PREFIX = /opt/v8builds

# The only place the version number shows up in the source tree.
# Kind of hard to not hard-code it, since this Makefile is
# here to make debuild happy, and debuild likes all such info to live in
# the source tree.

VERSION = 4.2.77
CONFIGS = release,debug

API = $(VERSION)
ABI = $(basename $(API))

UNAMEA := $(shell uname -a)
COND_DARWIN := $(if $(findstring Darwin,$(UNAMEA)),1)
COND_LINUX := $(if $(findstring Linux,$(UNAMEA)),1)
COND_WIN := $(if $(findstring CYGWIN,$(UNAMEA)),1)   # FIXME: work without uname by sensing $OS instead?
ifeq ($(COND_DARWIN),1)
TARGET_OS := mac
endif
ifeq ($(COND_LINUX),1)
TARGET_OS := linux
endif
ifeq ($(COND_WIN),1)
TARGET_OS := win
endif

PICKLE :=  v8-$(TARGET_OS)-$(VERSION)-pickled.tgz

all:
	echo "Assuming you've already run "
	echo "  sh build.sh -p $(PICKLE) -r $(VERSION)"
	echo "to download the source tarball."
	# Use -S since large apps that use v8 tend to explode with
	# violations of the ODR if v8 isn't a shared library.
	bash build.sh -S -c $(CONFIGS) -P $(PICKLE) -r $(VERSION)

.PHONY: clean

clean:
	rm -rf out

install:
	mkdir -p $(DESTDIR)$(PREFIX)/$(VERSION)
	OUT=`echo out/*.zip | sed 's/\.zip$$//'`; cd $$OUT; cp -a * $(DESTDIR)$(PREFIX)/$(VERSION)

uninstall:
	rm -rf $(DESTDIR)$(PREFIX)/$(VERSION)

# Propagate VERSION etc. into debian control files as needed
# Note: debian/rules can't invoke this (chicken-and-egg problem),
# so you have to do 'make versionstamp' after setting VERSION.
versionstamp:
	for file in control changelog; do sed 's/__VERSION__/$(VERSION)/g;s/__ABI__/$(ABI)/g;s/__API__/$(API)/g' < debian/$$file.in > debian/$$file; done
