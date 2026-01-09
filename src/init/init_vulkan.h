#ifndef INITH
#define INITH


#ifdef WINDOWS
#include "Volk/volk.h"
#else
#include "volk/volk.h"
#endif

#include <stdio.h>
#include <vulkan/vk_enum_string_helper.h>



#define CHECK_ELSE_RETURN(result, msg) ({\
    if (result != VK_SUCCESS) {\
        fprintf(stderr, "%s: %s\n", msg, string_VkResult(result));\
        return result;\
    }\
})

VkResult create_instance(VkInstance* p_instance, uint32_t nr_extensions, const char* const* vk_extensions, uint32_t nr_layers, const char* const* layers);

VkResult create_physical_device(VkPhysicalDevice* p_physical_device, uint32_t device_index, VkInstance instance);

VkResult create_device(
    VkDevice* p_device, uint32_t* p_queue_family_index, 
    VkPhysicalDevice physical_device,
    uint32_t nr_extensions, const char* const *extensions,
    void* features);


#endif 