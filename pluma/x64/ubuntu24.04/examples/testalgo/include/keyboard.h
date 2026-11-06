#ifndef PLUMA_DEVICE_KEYBOARD_H
#define PLUMA_DEVICE_KEYBOARD_H

#include <string>

#include "Pluma/Pluma.hpp"
#include "device.h"

using std::string;

namespace algorithm {
class Keyboard : public Device {
   public:
    string getDescription() override;
    ~Keyboard() = default;
};

// create KeyboardProvider, it implements DeviceProvider
PLUMA_INHERIT_PROVIDER(Keyboard, Device);
}  // namespace algorithm
#endif