
subdirs = src

all clean install uninstall ::
	set -e; for d in $(subdirs); do cd $$d && $(MAKE) $@; done

clean ::
	rm -f TAGS *~

tags :
	etags src/*.cc src/*.[ch] Activities/*.mm Activities/*.[chm]

.PHONY : tags
