import gdsfactory as gf

# Activate generic PDK just for core functionality
gf.gpdk.PDK.activate()

# 1. Load your routed GDS file
gds_path = "runs/RUN_2026-08-08_20-34-36/final/gds/ecg_monitor_top.gds"
c = gf.import_gds(gds_path)

# 2. Define a simplified 3D layer stack for Z-heights
sky130_stack = gf.technology.LayerStack(
    layers={
        "substrate": gf.technology.LayerLevel(layer=(235, 4), thickness=2.0, zmin=-2.0),
        "met1": gf.technology.LayerLevel(layer=(68, 20), thickness=0.3, zmin=1.0),
        "via1": gf.technology.LayerLevel(layer=(68, 44), thickness=0.5, zmin=1.3),
        "met2": gf.technology.LayerLevel(layer=(69, 20), thickness=0.4, zmin=1.8),
        "via2": gf.technology.LayerLevel(layer=(69, 44), thickness=0.6, zmin=2.2),
        "met3": gf.technology.LayerLevel(layer=(70, 20), thickness=0.7, zmin=2.8),
    }
)

# 3. Load our custom colors to prevent the LayerView crash
custom_views = gf.technology.LayerViews(filepath="sky130_views.yaml")

# 4. Extrude the 2D shapes into 3D meshes (passing in the custom views)
print("Extruding to 3D... this might take a minute.")
scene = c.to_3d(layer_stack=sky130_stack, layer_views=custom_views)

# 5. Export to a standard 3D file
scene.export("ecg_chip_3d.obj")
print("Export complete: ecg_chip_3d.obj")