--[[----------------------------------------------------------------------------

  Application Name: Visionary_S_AP_ExtractGround

  Summary:
  Extract a pointcloud only containing the ground surface and small things on it

  Description:
  This App searches for flat regions in the Z image and assumes the biggest flat region is the ground.
  The ground part of the image will be transfered to a pointcloud and a will be fitted to it.

  How to run:
  Start by running the app (F5) or debugging (F7+F10).
  Set a breakpoint on the first row inside the main function to debug step-by-step.
  See the results in the different image viewer on the DevicePage.

------------------------------------------------------------------------------]]
--Start of Global Scope---------------------------------------------------------
-- Variables, constants, serves etc. should be declared here.

-- the image provider object for the camera
local camera = Image.Provider.Camera.create()
camera:stop()
-- configure the camera
local config = Image.Provider.Camera.getDefaultConfig(camera)
-- only use the Z distance image and the RGB color image
Image.Provider.Camera.V3SXX2_1Config.setMaps(config, {"z_u16", "image_rgba"})
-- map color image to match the Z image
Image.Provider.Camera.V3SXX2_1Config.setColorMappingMode(config, "DISPARITY_ON_RGB")
-- parameters for the image acquisition - depending to the environment you're looking to
Image.Provider.Camera.V3SXX2_1Config.setAcquisitionMode(config, "NORMAL") -- NORMAL, HDR, HQM
Image.Provider.Camera.V3SXX2_1Config.setStereoIntegrationTime(config, 3000)
Image.Provider.Camera.V3SXX2_1Config.setColorIntegrationTime(config, 10000)
Image.Provider.Camera.V3SXX2_1Config.setFramePeriod(config, 1500000) -- micro seconds
-- set the config to the image provider object, it will be applied at the next 'camera:start()'
Image.Provider.Camera.setConfig(camera, config)

-- get the camera specific CameraModel
local camModel = camera:getInitialCameraModel()

-- initialize a PointCloudConversion Object
local pointCloudConverter = Image.PointCloudConversion.PlanarDistance.create()
pointCloudConverter:setCameraModel(camModel)

-- viewers
local view2D = View.create("view2D")
local view3D = View.create("view3D")
local pixelRegionDeco = View.PixelRegionDecoration.create()
pixelRegionDeco:setColor(0, 127, 195, 150)

---start the camera in the main function when the whole script was parsed
local function main()
  camera:start()
end

---@param image Image[]
---@param sensordata:SensorData
function handleOnNewImage(image, _)
  local starttime = DateTime.getTimestamp()

  -- find all flat Regions
  local surfaceRegions = Image.getFlatRegion(image[1], 5)
  surfaceRegions = Image.PixelRegion.findConnected(surfaceRegions, 2000, 614*512, 10)
  -- the found flats are ordered by size, so [1] means the biggest found flat region
  surfaceRegions[1] = Image.PixelRegion.dilate(surfaceRegions[1], 45)
  surfaceRegions[1] = Image.PixelRegion.erode(surfaceRegions[1], 45)
  surfaceRegions[1] = Image.PixelRegion.fillHoles(surfaceRegions[1])
  --surfaceRegions[1] = Image.PixelRegion.erode(surfaceRegions[1], 5)

  -- calculate point cloud for surface region
  local surfacePointCloud = pointCloudConverter:toPointCloud(image[1], image[1], surfaceRegions[1])

  -- fit a plane to the points of the surface
  local points, _ = surfacePointCloud:toPoints()
  local surfacePlane = Shape3D.fitPlane(points, "TRIMMED", "ABSOLUTE")

  -- Print the parameters of the plane to the console
  --local nx, ny, nz, dist = boxPlane:getPlaneParameters()
  --print(string.format("boxPlane --> nx: %.1f, ny: %.1f, nz: %.1f, distance: %.1f", nx, ny, nz, dist))

  local endtime = DateTime.getTimestamp()
  Log.warning("processing time: " .. (endtime - starttime) .. " ms" )

  view2D:clear()
  view3D:clear()

  -- visualize RGB image with overlay for the found surface
  view2D:addImage(image[2])
  view2D:addPixelRegion(surfaceRegions[1], pixelRegionDeco)

  -- visualize the surface pointcloud with the matching plane for these points
  view3D:addPointCloud(surfacePointCloud)
  if surfacePlane ~= nil then
    view3D:addShape(surfacePlane)
  end

  view2D:present()
  view3D:present()
end

-- register to OnNewImage with a Event Queue, so the images don't pile up during the long PointCloud calculation
eventQueueHandle = Script.Queue.create()
eventQueueHandle:setMaxQueueSize(1)
eventQueueHandle:setPriority("HIGH")
eventQueueHandle:setFunction(handleOnNewImage)
Image.Provider.Camera.register(camera, "OnNewImage", handleOnNewImage)

Script.register("Engine.OnStarted", main)