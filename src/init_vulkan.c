
#define VOLK_IMPLEMENTATION

#include "init_vulkan.h"
#include <vulkan/vk_enum_string_helper.h>
#include <stdio.h>




VkResult create_instance(uint32_t nr_extensions, const char* const* vk_extensions, VkInstance* pInstance) {

    const char * layers[] = {"VK_LAYER_KHRONOS_validation"};

    VkApplicationInfo app_info = {0};
    app_info.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
    app_info.apiVersion = VK_API_VERSION_1_3;

    VkInstanceCreateInfo info = {0};
    info.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    info.pApplicationInfo = &app_info;

    // info.enabledLayerCount = 1;
    // info.ppEnabledLayerNames = layers;
    
    info.enabledExtensionCount = nr_extensions;
    info.ppEnabledExtensionNames = vk_extensions;

    VkResult result = vkCreateInstance(&info, NULL, pInstance);

    return result;
}

VkResult create_device(VkDevice* pDevice, VkPhysicalDevice physical_device, uint32_t* pQueue_family_index, uint32_t nr_extensions, const char* const *extensions) {

    uint32_t nr_families;
    vkGetPhysicalDeviceQueueFamilyProperties2(physical_device, &nr_families, NULL);

    VkQueueFamilyProperties2 fam_props[nr_families];
    for (int i = 0; i < nr_families; i++) {
        fam_props[i].sType = VK_STRUCTURE_TYPE_QUEUE_FAMILY_PROPERTIES_2;
        fam_props[i].pNext = NULL;
    }
    vkGetPhysicalDeviceQueueFamilyProperties2(physical_device, &nr_families, fam_props);

    *pQueue_family_index = 0;
    for (int i = 0; i < nr_families; i--) {
        VkQueueFlagBits flags = fam_props[i].queueFamilyProperties.queueFlags;
        if ((flags & VK_QUEUE_GRAPHICS_BIT) && (flags & VK_QUEUE_COMPUTE_BIT) && (flags & VK_QUEUE_TRANSFER_BIT)) {
            *pQueue_family_index = i;
            break;
        }
    }


    

    float priority = 1.0;
    VkDeviceQueueCreateInfo queue_create_info = {0};
    queue_create_info.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
    queue_create_info.queueFamilyIndex = *pQueue_family_index;
    queue_create_info.queueCount = 1;
    queue_create_info.pQueuePriorities = &priority;


    VkPhysicalDeviceDynamicRenderingFeatures dynamic_rendering = {0};
    dynamic_rendering.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DYNAMIC_RENDERING_FEATURES;
    dynamic_rendering.dynamicRendering = VK_TRUE;

    VkPhysicalDeviceSynchronization2Features sync2_feature = {0};
    sync2_feature.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SYNCHRONIZATION_2_FEATURES;
    sync2_feature.pNext = &dynamic_rendering;
    sync2_feature.synchronization2 = VK_TRUE;

    VkDeviceCreateInfo dev_create_info = {0};
    dev_create_info.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
    dev_create_info.pNext = &sync2_feature;
    dev_create_info.queueCreateInfoCount = 1;
    dev_create_info.pQueueCreateInfos = &queue_create_info;
    dev_create_info.enabledExtensionCount = nr_extensions;
    dev_create_info.ppEnabledExtensionNames = extensions; 

    VkResult result = vkCreateDevice(physical_device, &dev_create_info, NULL, pDevice);
    

    return result;
}

VkResult init_vulkan(
        uint32_t nr_inst_extensions, const char* const* vk_inst_extensions, 
        uint32_t nr_dev_extensions, const char* const* dev_extensions, 
        VkInstance* pInstance, VkPhysicalDevice* pPhysicalDevice, VkDevice* pDevice, uint32_t* pQueue_family_index) 
{

    VkResult result = volkInitialize();
    CHECK_ELSE_RETURN(result, "volk initialization failed");

    result = create_instance(nr_inst_extensions, vk_inst_extensions, pInstance);
    CHECK_ELSE_RETURN(result, "failed to create vk instance");

    volkLoadInstance(*pInstance);

    // uint32_t nr_layers;
    // vkEnumerateInstanceLayerProperties(&nr_layers, NULL);
        
    // VkLayerProperties layer_properties[nr_layers];
    // vkEnumerateInstanceLayerProperties(&nr_layers, layer_properties); 

    // for (int i = 0; i < nr_layers; i++) {
    //     fprintf(stderr, "%s\n", layer_properties[i].layerName);
    // }

    uint32_t nr_devices;
    result = vkEnumeratePhysicalDevices(*pInstance, &nr_devices, NULL);
    CHECK_ELSE_RETURN(result, "failed to enumerate devices");

    VkPhysicalDevice devices[nr_devices];
    result = vkEnumeratePhysicalDevices(*pInstance, &nr_devices, devices);
    CHECK_ELSE_RETURN(result, "failed to enumerate all devices");

    *pPhysicalDevice = devices[0]; // TODO add parameter to control what device to use, default 0

    // for (int i = 0; i < nr_devices; i++) {
    //     VkPhysicalDeviceProperties2 props = {0};
    //     props.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2;
    //     vkGetPhysicalDeviceProperties2(devices[i], &props);
    //     printf("%s %s\n", props.properties.deviceName, string_VkPhysicalDeviceType(props.properties.deviceType));
    // }

    result = create_device(pDevice, *pPhysicalDevice, pQueue_family_index, nr_dev_extensions, dev_extensions);
    CHECK_ELSE_RETURN(result, "failed to create logical device");

    volkLoadDevice(*pDevice);

    
    return result;
}