
subdirs = src

all clean install :
	set -e; for d in $(subdirs); do cd $$d && $(MAKE) $@; done

tags :
	etags src/*.cc src/*.h
