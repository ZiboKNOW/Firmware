#!/bin/bash

# NextGen node/javascript top-level bindings test/s  - there are a few stages of test here..

# 1. ensure we've got the dependencies pre-built, such as js bindings, C bindings, and minimal compiled c targets.
# 2. run the static pre-canned JS create/pack tests in the 'mavlink.tests.js' files (ie assembling packets for sending)
# 3. capture all the packets that the C bindings test suite make, and try to parse them all with JS. ( incoming packet parsing)
# 4. make and run the complete autogenerated 'mocha' test suite/s that does byte-level verification of JS against the C bindings.

# We use '.tests.js' autogenerated javascript to build/pack one of each packet with test data for nominally sending

# utilise the C bindings and test suite to generate a bunch of mavlink data that we can run through the node/javascript parser
# we do this by executing ./generator/C/test/posix/testmav2.0_ardupilotmega to 
# run mavlink_test_all() from generator/C/include_v2.0/ardupilotmega/testsuite.h

# this script can be called manually by a human, or it can be triggered by a 'npm test' from the generator/javascript/ folder, so we handle either.

set -e
#set -x
RED='\033[1;31m'
GRN='\033[1;31m'
NC='\033[0m' # No Color

# 0 means low; 1 means some; 2 means high verbosity
VERBOSITY='0'
OUT0="/dev/stdout"
OUT1="/dev/null"
OUT2="/dev/null"

if [ "$VERBOSITY" = "1" ]; then
OUT1="/dev/stdout"
fi
if [ "$VERBOSITY" = "2" ]; then
OUT1="/dev/stdout"
OUT2="/dev/stdout"
fi


test -z "$MDEF" && MDEF="../message_definitions"


    # build js bindings we want to test
    printf "${RED}Generating JS-NextGen bindings to test...${NC}\n\n"
    sleep 1
    cd generator
    ./gen_js.sh > $OUT2
    cd ..


    # build C bindings to test the testsuite.js 'recieve' tester against.
    #    we quieten them as we really aren't testing THEM here.
    printf "${RED}Generating C bindings to test JS-NextGen against...${NC}\n\n"
    sleep 1
    ./tools/mavgen.py --lang C $MDEF/v1.0/ardupilotmega.xml -o generator/C/include_v1.0 --wire-protocol=1.0 > $OUT2
    ./tools/mavgen.py --lang C $MDEF/v1.0/ardupilotmega.xml -o generator/C/include_v2.0 --wire-protocol=2.0 > $OUT2


    #   we quieten them as we really aren't testing THEM here.
    printf "${RED}Compiling C bindings to test JS-NextGen against...${NC}\n\n"
    sleep 1
    pushd generator/C/test/posix  > $OUT2
    make clean testmav1.0_ardupilotmega testmav2.0_ardupilotmega testmav1.0_common testmav2.0_common > $OUT2
    popd  > $OUT2

     # need to install the bindings first to test them?
    printf "${RED}Installing just-generated npm package...${NC}\n\n"
    cd generator/javascript
    npm install 2>/dev/null > /dev/null
    cd ../..

   printf "${RED}JS-NextGen PRETEST setup done.${NC}\n\n"




# run the automatically generated tool for build/pack, ie create and pack one of everything, no byte-level checking of the packed results tho, comes later.
printf "${RED}Running non-NPM JS-NextGen create/pack tests ...${NC}\n\n"
sleep 1
node generator/javascript/implementations/mavlink_ardupilotmega_v2.0/mavlink.tests.js > $OUT1
node generator/javascript/implementations/mavlink_ardupilotmega_v1.0/mavlink.tests.js > $OUT1
node generator/javascript/implementations/mavlink_common_v2.0/mavlink.tests.js > $OUT1
node generator/javascript/implementations/mavlink_common_v1.0/mavlink.tests.js > $OUT1


# piping the wire-ready hex-output from the C bindings into the node bindings per-packet and receive each of them.
printf "${RED}Streaming C test data into JS-NextGen for pushBuffer/parseBuffer tests${NC}\n\n"
sleep 1
pushd generator/C/test/posix  > $OUT2
make testmav1.0_common testmav2.0_common testmav1.0_ardupilotmega testmav2.0_ardupilotmega
./testmav1.0_ardupilotmega | grep '^fe' | node ../../../../examples/testparser.js ardupilotmega 1.0 $VERBOSITY
./testmav2.0_ardupilotmega | grep '^fd' | node ../../../../examples/testparser.js ardupilotmega 2.0 $VERBOSITY 
./testmav1.0_common | grep '^fe' | node ../../../../examples/testparser.js common 1.0 $VERBOSITY
./testmav2.0_common | grep '^fd' | node ../../../../examples/testparser.js common 2.0 $VERBOSITY
popd  > $OUT2


# we also have a big collection ~990 of mocha tests based on C output like the above but more thorough, this includes byte-level 
# checking of the packed results etc.
# u can/should also run the ~990 or more mocha tests we just made:  
#( this uses generator/javascript/package.json -> runs make_tests.py -> outputs made_tests.js -> which are then executed by 'mocha test' )
echo "tip: if not bring auto-run as a auto-test, u can run the next-stage of tests with mocha here:"
echo "cd generator/javascript"
echo "npm test"
echo "cd -"


printf "\n${RED}JS-NextGen Testing done.${NC}\n\n"
