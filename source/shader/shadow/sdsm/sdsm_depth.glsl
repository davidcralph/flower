#version 460

/*
** Physical based render code, develop by engineer: qiutanguu.
*/

#extension GL_EXT_nonuniform_qualifier : enable
#extension GL_GOOGLE_include_directive : enable

#include "sdsm_common.glsl"

struct VS2PS
{
    vec2 uv0;
};

layout (set = 1, binding = 0) buffer BindlessSSBOVertices{ float data[]; } verticesArray[];
layout (set = 2, binding = 0) buffer BindlessSSBOIndices{ uint data[]; } indicesArray[];
layout (set = 3, binding = 0) uniform texture2D bindlessTexture2D[];
layout (set = 4, binding = 0) uniform sampler bindlessSampler[];

vec4 texlod(uint texId, uint samplerId, vec2 uv, float lod)
{
    return textureLod(sampler2D(bindlessTexture2D[nonuniformEXT(texId)], bindlessSampler[nonuniformEXT(samplerId)]), uv, lod);
}

vec4 tex(uint texId,uint samplerId,vec2 uv)
{
    return texture(sampler2D(bindlessTexture2D[nonuniformEXT(texId)], bindlessSampler[nonuniformEXT(samplerId)]), uv);
}

#ifdef VERTEX_SHADER ///////////// vertex shader start 

layout(location = 0) out flat uint outObjectId;
layout(location = 1) out VS2PS vsOut;

void main()
{
    // Draw id need bias cascade.
    const uint drawId = gl_DrawID + cascadeId * perCascadeMaxCount;

    // Load object data.
    outObjectId = indirectCommands[drawId].objectId;
    const StaticMeshPerObjectData objectData = objectDatas[outObjectId];

    // We get bindless array id first.
    const uint indicesId = objectData.indicesArrayId;
    const uint positionId = objectData.positionsArrayId;
    const uint uv0Id = objectData.uv0sArrayId;

    vec3 position;
    vec2 uv0;

    // Vertex count same with index count, so vertex index same with index index.
    const uint indexId = gl_VertexIndex;

    // Then fetech vertex index from indices array.
    const uint vertexId = indicesArray[nonuniformEXT(indicesId)].data[indexId];

    position.x = verticesArray[nonuniformEXT(positionId)].data[vertexId * kPositionStrip + 0];
    position.y = verticesArray[nonuniformEXT(positionId)].data[vertexId * kPositionStrip + 1];
    position.z = verticesArray[nonuniformEXT(positionId)].data[vertexId * kPositionStrip + 2];

    uv0.x = verticesArray[nonuniformEXT(uv0Id)].data[vertexId * kUv0Strip + 0];
    uv0.y = verticesArray[nonuniformEXT(uv0Id)].data[vertexId * kUv0Strip + 1];

    vsOut.uv0 = uv0;

    // All ready, start to do vertex space-transform.
    const mat4 modelMatrix = objectData.modelMatrix;

    // Local vertex position.
    const vec4 localPosition = vec4(position, 1.0f);
    const vec4 worldPosition = modelMatrix * localPosition;

    // Convert to clip space.
    gl_Position = cascadeInfos[cascadeId].viewProj * worldPosition;
}

#endif /////////////////////////// vertex shader end

#ifdef PIXEL_SHADER ////////////// pixel shader start 

layout(location = 0) in flat uint inObjectId;
layout(location = 1) in VS2PS vsIn;

layout(location = 0) out vec4 outColor;

void main()
{
    const StaticMeshPerObjectData objectData = objectDatas[inObjectId];
    const MaterialStandardPBR mat = objectData.material;

    const vec4 baseColor = tex(mat.baseColorId, mat.baseColorSampler, vsIn.uv0);
    if(baseColor.a < mat.cutoff)
    {
        discard;
    }
    outColor = vec4(0.0f);
}

#endif //////////////////////////// pixel shader end