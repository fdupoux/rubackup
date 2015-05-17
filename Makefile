PROGNAME="rubackup"
PROGGITDATE=`git log -1 --pretty=format:%ct`
PROGVERSION=`cat src/rubackup.rb | grep -F 'RUBACKUP_VERSION = ' | grep -Po '\"[^"]+\"' | sed -e 's/"//g'`
PROGRELEASE=`cat RELEASE 2>/dev/null| echo '1'`

all: rpm

clean:  
	rm -rf rpmbuild

rpm: clean
	echo $(PROGGITDATE) > GITDATE
	mkdir -p rpmbuild/{BUILD,BUILDROOT,RPMS,RPMS/noarch,SOURCES,SPECS,SRPMS}
	mkdir -p $(PROGNAME)-$(PROGVERSION)
	rsync -a src ChangeLog README rubackup.spec LICENSE Makefile $(PROGNAME)-$(PROGVERSION)/
	tar cfz rpmbuild/SOURCES/$(PROGNAME)-$(PROGVERSION).tar.gz $(PROGNAME)-$(PROGVERSION)
	rm -rf $(PROGNAME)-$(PROGVERSION)
	rpmbuild --define "_topdir %(pwd)/rpmbuild" --define "progversion $(PROGVERSION)" --define "progrelease $(PROGRELEASE)" -ba $(PROGNAME).spec
