
subdirs = lib

all clean install uninstall ::
	set -e; for d in $(subdirs); do cd $$d && $(MAKE) $@; done

clean ::
	rm -f TAGS *~

tags :
	etags lib/*.cc lib/*.[ch] mac/*.mm mac/*.[chm]

.PHONY : tags
