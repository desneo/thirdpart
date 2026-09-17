#include "Pluma/Connector.hpp"

#include "keyboard.h"

namespace algorithm {

PLUMA_CONNECTOR
bool connectToPlumaHost(pluma::Host& host) {
    // add a keyboard provider to host
    host.add(new KeyboardProvider());
    return true;
}

}  // namespace jrptz