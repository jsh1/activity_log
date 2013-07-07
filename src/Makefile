
product = gps-test
objects = gps-test.o gps-activity.o gps-parser.o tcx-parser.o fit-parser.o
includes = -I/usr/include/libxml2
libraries = -lxml2

OPTIMIZATION_CFLAGS := -O0
DEBUG_CFLAGS := -g
WARNING_CFLAGS := -Wall -Werror

compiler_flags = $(includes) $(CXXFLAGS) $(OPTIMIZATION_CFLAGS) \
	$(DEBUG_CFLAGS) $(WARNING_CFLAGS)

$(product) : $(objects)
	$(CXX) $^ -o $@ $(LDFLAGS) $(libraries)

%.o : %.cc
	$(CXX) -c $^ -o $@ $(compiler_flags)

clean :
	rm -f $(product) $(objects) *~
