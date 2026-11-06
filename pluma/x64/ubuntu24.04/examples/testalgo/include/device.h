#ifndef PLUMA_DEVICE_H
#define PLUMA_DEVICE_H

#include <string>

#include "Pluma/Pluma.hpp"

using std::string;

namespace algorithm {
class Device {
   public:
    virtual string getDescription() = 0;;
    virtual ~Device() = default;
};
// create DevicedProvider class
PLUMA_PROVIDER_HEADER(Device);
}  // namespace jrptz
#endif