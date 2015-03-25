/* rapt - RichieSam's Adventures in Path Tracing
 *
 * rapt is the legal property of Adrian Astley
 * Copyright Adrian Astley 2015
 */

#include "basic_path_tracer/path_trace.cuh"

#include "scene/device_camera.h"
#include "scene/ray_creation.cuh"
#include "scene/materials.h"

#define BACKFACE_CULL_SPHERES
#include "scene/object_intersection.cuh"

#include <device_launch_parameters.h>
#include <float.h>



__global__ void PathTraceKernel(unsigned char *textureData, uint width, uint height, size_t pitch, DeviceCamera *g_camera, Scene::SceneObjects *g_sceneObjects, uint hashedFrameNumber) {
	int x = blockIdx.x * blockDim.x + threadIdx.x;
	int y = blockIdx.y * blockDim.y + threadIdx.y;

	// Create a local copy of the arguments
	DeviceCamera camera = *g_camera;
	Scene::SceneObjects sceneObjects = *g_sceneObjects;

	// Global threadId
	int threadId = (blockIdx.x + blockIdx.y * gridDim.x) * (blockDim.x * blockDim.y) + (threadIdx.y * blockDim.x) + threadIdx.x;

	// Create random number generator
	curandState randState;
	curand_init(hashedFrameNumber + threadId, 0, 0, &randState);

	// Calculate the first ray for this pixel
	Scene::Ray ray = {camera.Origin, CalculateRayDirectionFromPixel(x, y, width, height, camera, &randState)};


	float3 pixelColor = make_float3(0.0f, 0.0f, 0.0f);
	float3 accumulatedMaterialColor = make_float3(1.0f, 1.0f, 1.0f);

	// Bounce the ray around the scene
	for (uint bounces = 0; bounces < 10; ++bounces) {
		// Initialize the intersection variables
		float closestIntersection = FLT_MAX;
		float3 normal;
		Scene::LambertMaterial material;

		TestSceneIntersection(ray, sceneObjects, &closestIntersection, &normal, &material);

		// Find out if we hit anything
		if (closestIntersection < FLT_MAX) {
			// We hit an object
			accumulatedMaterialColor *= materialColor;

			ray.Origin = ray.Origin + ray.Direction * closestIntersection;
			ray.Direction = CreateRandomDirectionInNormalHemisphere(normal, &randState);
		} else {
			// We didn't hit anything
			// Use the sky color instead and stop bouncing rays
			pixelColor = make_float3(0.846, 0.933, 0.949) * accumulatedMaterialColor;

			break;
		}
	}
	

	if (x < width && y < height) {
		// Get a pointer to the pixel at (x,y)
		float *pixel = (float *)(textureData + y * pitch) + 4 /*RGBA*/ * x;

		// Write out pixel data
		pixel[0] += pixelColor.x;
		pixel[1] += pixelColor.y;
		pixel[2] += pixelColor.z;
		// Ignore alpha, since it's hardcoded to 1.0f in the display
		// We have to use a RGBA format since CUDA-DirectX interop doesn't support R32G32B32_FLOAT
	}
}
