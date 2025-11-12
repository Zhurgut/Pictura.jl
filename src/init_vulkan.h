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

VkResult init_vulkan(
        uint32_t nr_inst_extensions, const char* const* vk_inst_extensions, 
        uint32_t nr_dev_extensions, const char* const* dev_extensions, 
        VkInstance* pInstance, VkDevice* pDevice, uint32_t* pQueue_family_index);


#endif 