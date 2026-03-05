
#define VOLK_IMPLEMENTATION

#include "init_vulkan.h"

#include <stdio.h>
#include <string.h>




VkResult create_instance(VkInstance* p_instance, uint32_t nr_extensions, const char* const* vk_extensions, uint32_t nr_layers, const char* const* layers) {

    VkResult result = volkInitialize();
    CHECK_ELSE_RETURN(result, "volk initialization failed");


    uint32_t api_version;

    if (vkEnumerateInstanceVersion) {
        result = vkEnumerateInstanceVersion(&api_version);
    } else {
        CHECK_ELSE_RETURN(VK_ERROR_INITIALIZATION_FAILED, "vkEnumerateInstanceVersion not available -> only vulkan 1.0 available (1.3 required)");
    }

    CHECK_ELSE_RETURN(result, "failed to enumerateInstanceVersion");

    if (api_version < VK_API_VERSION_1_3) {
        fprintf(stderr, "supported version on instance level: %d.%d.%d\n", VK_API_VERSION_MAJOR(api_version), VK_API_VERSION_MINOR(api_version), VK_API_VERSION_PATCH(api_version));
        CHECK_ELSE_RETURN(VK_ERROR_INITIALIZATION_FAILED, "vulkan 1.3 not supported");
    }


    VkApplicationInfo app_info = {0};
    app_info.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
    app_info.apiVersion = VK_API_VERSION_1_3;

    VkInstanceCreateInfo info = {0};
    info.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    info.pApplicationInfo = &app_info;
    
    info.enabledExtensionCount = nr_extensions;
    info.ppEnabledExtensionNames = vk_extensions;

    result = vkCreateInstance(&info, NULL, p_instance);
    CHECK_ELSE_RETURN(result, "failed to create vk instance");

    volkLoadInstance(*p_instance);

    return result;
}


VkResult create_physical_device(VkPhysicalDevice* p_physical_device, uint32_t device_index, VkInstance instance) {

    uint32_t nr_devices;
    VkResult result = vkEnumeratePhysicalDevices(instance, &nr_devices, NULL);
    CHECK_ELSE_RETURN(result, "failed to get number of devices");

    if (device_index >= nr_devices) {
        CHECK_ELSE_RETURN(VK_ERROR_INITIALIZATION_FAILED , "device index out of bounds");
    }

    VkPhysicalDevice devices[nr_devices];
    result = vkEnumeratePhysicalDevices(instance, &nr_devices, devices);
    CHECK_ELSE_RETURN(result, "failed to enumerate devices");

    *p_physical_device = devices[device_index];

    VkPhysicalDeviceProperties2 props = {0};
    props.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2;
    vkGetPhysicalDeviceProperties2(*p_physical_device, &props);

    uint32_t api_version = props.properties.apiVersion;
    if (api_version < VK_API_VERSION_1_3) {
        fprintf(stderr, "supported version on device level: %d.%d.%d\n", VK_API_VERSION_MAJOR(api_version), VK_API_VERSION_MINOR(api_version), VK_API_VERSION_PATCH(api_version));
        CHECK_ELSE_RETURN(VK_ERROR_INITIALIZATION_FAILED, "vulkan 1.3 not supported");
    }
    
    return result;
}



VkResult create_device(
        VkDevice* p_device, uint32_t* p_queue_family_index, 
        VkPhysicalDevice physical_device,
        uint32_t nr_extensions, const char* const *extensions,
        void* features) 
{   
    
    uint32_t nr_families;
    vkGetPhysicalDeviceQueueFamilyProperties2(physical_device, &nr_families, NULL);

    VkQueueFamilyProperties2 fam_props[nr_families];
    for (int i = 0; i < nr_families; i++) {
        fam_props[i].sType = VK_STRUCTURE_TYPE_QUEUE_FAMILY_PROPERTIES_2;
        fam_props[i].pNext = NULL;
    }
    vkGetPhysicalDeviceQueueFamilyProperties2(physical_device, &nr_families, fam_props);

    *p_queue_family_index = 0;
    int success = 0;
    for (int i = 0; i < nr_families; i--) {
        VkQueueFlagBits flags = fam_props[i].queueFamilyProperties.queueFlags;
        if (flags & (VK_QUEUE_GRAPHICS_BIT | VK_QUEUE_COMPUTE_BIT | VK_QUEUE_TRANSFER_BIT)) {
            *p_queue_family_index = i;
            success = 1;
            break;
        }
    }

    if (!success) {
        CHECK_ELSE_RETURN(VK_ERROR_INITIALIZATION_FAILED , "didnt find a queue with all three of graphics, compute & transfer bits");
    }

  

    float priority = 1.0;
    VkDeviceQueueCreateInfo queue_create_info = {0};
    queue_create_info.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
    queue_create_info.queueFamilyIndex = *p_queue_family_index;
    queue_create_info.queueCount = 1;
    queue_create_info.pQueuePriorities = &priority;



    VkDeviceCreateInfo dev_create_info = {0};
    dev_create_info.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
    dev_create_info.pNext = features;
    dev_create_info.queueCreateInfoCount = 1;
    dev_create_info.pQueueCreateInfos = &queue_create_info;
    dev_create_info.enabledExtensionCount = nr_extensions;
    dev_create_info.ppEnabledExtensionNames = extensions; 

    VkResult result = vkCreateDevice(physical_device, &dev_create_info, NULL, p_device);
    CHECK_ELSE_RETURN(result, "failed to create logical device");

    volkLoadDevice(*p_device);
    

    return result;
}