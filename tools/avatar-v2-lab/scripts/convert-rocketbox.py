"""Convert one MIT Rocketbox facial FBX into a TalkingHead-compatible GLB."""

import os
import sys

import bpy


VISeme_NAMES = {
    "AA_VI_00_Sil": "viseme_sil",
    "AA_VI_01_PP": "viseme_PP",
    "AA_VI_02_FF": "viseme_FF",
    "AA_VI_03_TH": "viseme_TH",
    "AA_VI_04_DD": "viseme_DD",
    "AA_VI_05_KK": "viseme_kk",
    "AA_VI_06_CH": "viseme_CH",
    "AA_VI_07_SS": "viseme_SS",
    "AA_VI_08_nn": "viseme_nn",
    "AA_VI_09_RR": "viseme_RR",
    "AA_VI_10_aa": "viseme_aa",
    "AA_VI_11_E": "viseme_E",
    "AA_VI_12_I": "viseme_I",
    "AA_VI_13_O": "viseme_O",
    "AA_VI_14_U": "viseme_U",
}

ARKit_NAMES = {
    "AK_01_BrowDownLeft": "browDownLeft",
    "AK_02_BrowDownRight": "browDownRight",
    "AK_03_BrowInnerUp": "browInnerUp",
    "AK_04_BrowOuterUpLeft": "browOuterUpLeft",
    "AK_05_BrowOuterUpRight": "browOuterUpRight",
    "AK_06_CheekPuff": "cheekPuff",
    "AK_07_CheekSquintLeft": "cheekSquintLeft",
    "AK_08_CheekSquintRight": "cheekSquintRight",
    "AK_09_EyeBlinkLeft": "eyeBlinkLeft",
    "AK_10_EyeBlinkRight": "eyeBlinkRight",
    "AK_11_EyeLookDownLeft": "eyeLookDownLeft",
    "AK_12_EyeLookDownRight": "eyeLookDownRight",
    "AK_13_EyeLookInLeft": "eyeLookInLeft",
    "AK_14_EyeLookInRight": "eyeLookInRight",
    "AK_15_EyeLookOutLeft": "eyeLookOutLeft",
    "AK_16_EyeLookOutRight": "eyeLookOutRight",
    "AK_17_EyeLookUpLeft": "eyeLookUpLeft",
    "AK_18_EyeLookUpRight": "eyeLookUpRight",
    "AK_19_EyeSquintLeft": "eyeSquintLeft",
    "AK_20_EyeSquintRight": "eyeSquintRight",
    "AK_21_EyeWideLeft": "eyeWideLeft",
    "AK_22_EyeWideRight": "eyeWideRight",
    "AK_23_JawForward": "jawForward",
    "AK_24_JawLeft": "jawLeft",
    "AK_25_JawOpen": "jawOpen",
    "AK_26_JawRight": "jawRight",
    "AK_27_MouthClose": "mouthClose",
    "AK_28_MouthDimpleLeft": "mouthDimpleLeft",
    "AK_29_MouthDimpleRight": "mouthDimpleRight",
    "AK_30_MouthFrownLeft": "mouthFrownLeft",
    "AK_31_MouthFrownRight": "mouthFrownRight",
    "AK_32_MouthFunnel": "mouthFunnel",
    "AK_33_MouthLeft": "mouthLeft",
    "AK_34_MouthLowerDownLeft": "mouthLowerDownLeft",
    "AK_35_MouthLowerDownRight": "mouthLowerDownRight",
    "AK_36_MouthPressLeft": "mouthPressLeft",
    "AK_37_MouthPressRight": "mouthPressRight",
    "AK_38_MouthPucker": "mouthPucker",
    "AK_39_MouthRight": "mouthRight",
    "AK_40_MouthRollLower": "mouthRollLower",
    "AK_41_MouthRollUpper": "mouthRollUpper",
    "AK_42_MouthShrugLower": "mouthShrugLower",
    "AK_43_MouthShrugUpper": "mouthShrugUpper",
    "AK_44_MouthSmileLeft": "mouthSmileLeft",
    "AK_45_MouthSmileRight": "mouthSmileRight",
    "AK_46_MouthStretchLeft": "mouthStretchLeft",
    "AK_47_MouthStretchRight": "mouthStretchRight",
    "AK_48_MouthUpperUpLeft": "mouthUpperUpLeft",
    "AK_49_MouthUpperUpRight": "mouthUpperUpRight",
    "AK_50_NoseSneerLeft": "noseSneerLeft",
    "AK_51_NoseSneerRight": "noseSneerRight",
    "AK_52_TongueOut": "tongueOut",
}

BONE_NAMES = {
    "Bip01 Pelvis": "Hips",
    "Bip01 Spine": "Spine",
    "Bip01 Spine1": "Spine1",
    "Bip01 Spine2": "Spine2",
    "Bip01 Neck": "Neck",
    "Bip01 Head": "Head",
    "Bip01 REye": "RightEye",
    "Bip01 LEye": "LeftEye",
    "Bip01 MJaw": "Jaw",
    "Bip01 L Clavicle": "LeftShoulder",
    "Bip01 L UpperArm": "LeftArm",
    "Bip01 L Forearm": "LeftForeArm",
    "Bip01 L Hand": "LeftHand",
    "Bip01 R Clavicle": "RightShoulder",
    "Bip01 R UpperArm": "RightArm",
    "Bip01 R Forearm": "RightForeArm",
    "Bip01 R Hand": "RightHand",
    "Bip01 L Thigh": "LeftUpLeg",
    "Bip01 L Calf": "LeftLeg",
    "Bip01 L Foot": "LeftFoot",
    "Bip01 L Toe0": "LeftToeBase",
    "Bip01 R Thigh": "RightUpLeg",
    "Bip01 R Calf": "RightLeg",
    "Bip01 R Foot": "RightFoot",
    "Bip01 R Toe0": "RightToeBase",
}

for side, prefix in (("L", "Left"), ("R", "Right")):
    for source_digit, target in (("0", "Thumb"), ("1", "Index"), ("2", "Middle"), ("3", "Ring"), ("4", "Pinky")):
        for source_suffix, target_number in (("", "1"), ("1", "2"), ("2", "3")):
            BONE_NAMES[f"Bip01 {side} Finger{source_digit}{source_suffix}"] = f"{prefix}Hand{target}{target_number}"


def args_after_separator():
    args = sys.argv[sys.argv.index("--") + 1 :]
    if len(args) != 2:
        raise SystemExit("expected input.fbx output.glb")
    return args


def main():
    source, output = args_after_separator()
    bpy.ops.import_scene.fbx(filepath=source, automatic_bone_orientation=False)
    bpy.context.scene.unit_settings.scale_length = 100.0

    armature = next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE")
    mesh = next(obj for obj in bpy.context.scene.objects if obj.type == "MESH" and obj.name != "Cube")
    # The FBX armature's rest coordinates are centimetres while the mesh is
    # already expressed through the imported object transform. Normalize the
    # bone rest coordinates without applying the parent transform to the mesh
    # data; applying the object transform would double-scale the skin on glTF
    # export.
    bpy.context.view_layer.objects.active = armature
    armature.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for bone in armature.data.edit_bones:
        bone.head *= 0.01
        bone.tail *= 0.01
    bpy.ops.object.mode_set(mode="OBJECT")
    # TalkingHead locates the skinned root by this stable object name.
    armature.name = "Armature"

    texture_root = os.path.abspath(os.path.join(os.path.dirname(source), "..", "Textures"))
    for image in bpy.data.images:
        candidate = os.path.join(texture_root, os.path.basename(image.filepath))
        if os.path.exists(candidate):
            image.filepath = candidate
            image.reload()

    for bone in armature.data.bones:
        if bone.name in BONE_NAMES:
            bone.name = BONE_NAMES[bone.name]

    if mesh.data.shape_keys:
        for key in mesh.data.shape_keys.key_blocks:
            key.name = VISeme_NAMES.get(key.name, ARKit_NAMES.get(key.name, key.name))

    for obj in list(bpy.context.scene.objects):
        if obj.type in {"CAMERA", "LIGHT"} or obj.name == "Cube":
            bpy.data.objects.remove(obj, do_unlink=True)

    # Keep all texture maps inside the GLB so the Flutter Web asset is truly
    # self-hosted and does not depend on the Rocketbox repository at runtime.
    bpy.ops.file.pack_all()
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type in {"MESH", "ARMATURE"}:
            obj.select_set(True)
    bpy.context.view_layer.objects.active = armature

    bpy.ops.export_scene.gltf(
        filepath=output,
        export_format="GLB",
        export_apply=False,
        export_animations=False,
        export_morph=True,
        export_skins=True,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_yup=True,
    )
    print("Wrote", output, "shape keys", len(mesh.data.shape_keys.key_blocks) if mesh.data.shape_keys else 0)


if __name__ == "__main__":
    main()
