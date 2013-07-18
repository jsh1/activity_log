
# files

library_products = libact.a
bin_products = act act-new act-gps-test
symlink_products = act-import

libact.a_objects =		\
	act-activity.o		\
	act-arguments.o		\
	act-config.o		\
	act-format.o		\
	act-gps-activity.o	\
	act-gps-parser.o	\
	act-gps-fit-parser.o	\
	act-gps-tcx-parser.o	\
	act-util.o

act_libraries = -lact
act_objects =			\
	act-driver.o
act_deps = libact.a

act-new_libraries = -lact -lxml2
act-new_objects =		\
	act-new.o
act-new_deps = libact.a

act-import_src = act-new

act-gps-test_libraries = -lact -lxml2
act-gps-test_objects =		\
	act-gps-test.o
act-gps-test_deps = libact.a

# compilers

CXX = clang++
CC = clang

includes = -I/usr/include/libxml2
cxx_standard_flags = -std=c++11
optimization_cflags := -O0
debug_cflags := -g
warning_cflags := -Wall -Werror

compiler_flags = $(includes) $(CXXFLAGS) $(cxx_standard_flags) \
	$(optimization_cflags) $(debug_cflags) $(warning_cflags)

# rules

all : $(library_products) $(bin_products) $(symlink_products)

define library_rules
$(1) : $$($(1)_objects)
	$$(AR) -rcs $$@ $$^
clean ::
	rm -f $(1) $$($(1)_objects)
-include $$(patsubst %.o,.%.d,$$($(1)_objects))
endef

define bin_rules
$(1) : $$($(1)_objects) $$($(1)_deps)
	$$(CXX) $$($(1)_objects) -o $$@ $$(LDFLAGS) -L. $$($(1)_libraries)
clean ::
	rm -f $(1) $$($(1)_objects)
-include $$(patsubst %.o,.%.d,$$($(1)_objects))
endef

define symlink_rules
$(1) :
	ln -sf $$($(1)_src) $$@
clean ::
	rm -f $(1)
endef

$(foreach prod,$(library_products),$(eval $(call library_rules,$(prod))))
$(foreach prod,$(bin_products),$(eval $(call bin_rules,$(prod))))
$(foreach prod,$(symlink_products),$(eval $(call symlink_rules,$(prod))))

%.o : %.cc
	$(CXX) -c $(filter %.cc,$^) -o $@ $(compiler_flags)

.%.d : %.cc
	@echo make-dep $<
	@$(SHELL) -ec '$(CXX) -MM $(includes) $(CXXFLAGS) \
	  $(cxx_standard_flags) $(filter %.cc,$<) \
	  | sed '\''s/$*\.o/& $*.lo .$*\.d/g'\'' > $@'

clean ::
	rm -f *~ .#* .*.d
