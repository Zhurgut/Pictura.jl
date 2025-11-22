#ifndef INITH
#define INITH



#include <Volk/volk.h>
#include <stdio.h>
#include <vulkan/vk_enum_string_helper.h>



#define CHECK_ELSE_RETURN(result, msg) ({\
    if (result != VK_SUCCESS) {\
        fprintf(stderr, "%s: %s\n", msg, string_VkResult(result));\
        return result;\
    }\
})

VkResult create_instance_and_physical_device(
        uint32_t nr_inst_extensions, const char* const* vk_inst_extensions, 
        VkInstance* pInstance, VkPhysicalDevice* pPhysicalDevice);

VkResult create_device(
        VkPhysicalDevice physical_device,
        VkDevice* pDevice, uint32_t* pQueue_family_index, 
        uint32_t nr_extensions, const char* const *extensions);


#endif 