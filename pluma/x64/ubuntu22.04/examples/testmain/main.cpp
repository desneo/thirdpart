#include <iostream>
#include <vector>

#include "Pluma/Pluma.hpp"
#include "device.h"

using namespace algorithm;

//  插件宏定义
PLUMA_PROVIDER_SOURCE(Device, 1, 1);

int main() {
    pluma::Pluma plugins;
    // Tell plugins manager to accept providers of the type DeviceProvider
    plugins.acceptProviderType<DeviceProvider>();
    // Load library "standard_devices" from folder "plugins"
    plugins.loadFromFolder("./plugins");

    // Get device providers into a vector
    std::vector<DeviceProvider*> providers;
    plugins.getProviders(providers);

    std::cout<<1111<<std::endl;

    // create a Device from the first provider
    if (!providers.empty()) {
        std::cout<<1111<<std::endl;
        Device* myDevice = providers.front()->create();
        std::cout<<1111<<std::endl;
        // do something with myDevice
        std::cout << myDevice->getDescription() << std::endl;
        // and delete it in the end
        delete myDevice;
    }
    return 0;
}