import trimesh
import numpy as np
from scipy.spatial.transform import Rotation as R
import json
import os

# --- CONFIGURATION ---
MODEL_PATH = 'assets/models/d20.glb'
UP_VECTOR = np.array([0, 1, 0])
BACKUP_FILE = 'mapping_backup.json'

def get_simplified_faces(mesh):
    # (This function is correct and remains unchanged)
    simplified_faces = []
    rounded_normals = np.round(mesh.face_normals, 2)
    unique_normals = np.unique(rounded_normals, axis=0)
    for unique_normal in unique_normals:
        group = np.where(np.all(rounded_normals == unique_normal, axis=1))[0]
        normals_in_group = mesh.face_normals[group]
        areas_in_group = mesh.area_faces[group]
        avg_normal = np.mean(normals_in_group, axis=0)
        total_area = np.sum(areas_in_group)
        simplified_faces.append({
            'normal': avg_normal / np.linalg.norm(avg_normal),
            'area': total_area
        })
    simplified_faces.sort(key=lambda x: x['area'], reverse=True)
    return simplified_faces[:20]

def generate_rotations(face_number_map):
    # (This function is correct and remains unchanged)
    print("\n" + "=" * 80)
    print("--- MAPPING COMPLETE! JAVASCRIPT ROTATION GENERATOR ---")
    print("Copy the following lines into your 'targetRotations' object:")
    print("=" * 80)
    js_output = "const targetRotations = {\n"
    for number, face_normal in sorted(face_number_map.items()):
        rotation, _ = R.align_vectors([UP_VECTOR], [face_normal])
        rot_vec = rotation.as_rotvec()
        angle = np.linalg.norm(rot_vec)
        axis = rot_vec / angle if angle > 1e-6 else np.array([0, 0, 1])
        js_line = (f"    {number}: new CANNON.Quaternion().setFromAxisAngle("
                   f"new CANNON.Vec3({axis[0]:.6f}, {axis[1]:.6f}, {axis[2]:.6f}), {angle:.6f}),")
        js_output += js_line + "\n"
    js_output += "};"
    print(js_output)
    print("=" * 80)

def save_progress(progress_map):
    """Saves the current mapping progress to a JSON file."""
    # Convert numpy arrays to lists for JSON compatibility
    savable_map = {str(k): v.tolist() for k, v in progress_map.items()}
    with open(BACKUP_FILE, 'w') as f:
        json.dump(savable_map, f, indent=4)
    print(f"Progress saved to {BACKUP_FILE}")

def load_progress():
    """Loads mapping progress from the JSON file if it exists."""
    if os.path.exists(BACKUP_FILE):
        with open(BACKUP_FILE, 'r') as f:
            loaded_map = json.load(f)
            # Convert lists back to numpy arrays
            progress_map = {int(k): np.array(v) for k, v in loaded_map.items()}
            print(f"SUCCESS: Loaded {len(progress_map)} mapped faces from {BACKUP_FILE}")
            return progress_map
    return {}

if __name__ == '__main__':
    try:
        mesh = trimesh.load(MODEL_PATH, force='mesh')
        print(f"Successfully loaded model '{MODEL_PATH}'.")
        
        simplified_faces = get_simplified_faces(mesh)
        if len(simplified_faces) < 20:
            raise ValueError(f"Could only find {len(simplified_faces)} distinct faces.")

        print("\n--- Interactive Face Mapping GUI ---")
        
        # Load any existing progress
        final_face_map = load_progress()
        
        # The loop will now start from the next unmapped number
        for number_to_map in range(1, 21):
            if number_to_map in final_face_map:
                print(f"Skipping number '{number_to_map}' - already mapped.")
                continue

            print("\n" + "-"*50)
            print(f"--> Please orient the die to show the number '{number_to_map}'")
            print("--> Use your mouse to rotate the die in the 3D window.")
            print("--> Once the number is facing you, CLOSE THE 3D WINDOW.")
            print("-" * 50)
            
            # This is the original, working viewer logic
            scene = trimesh.Scene(mesh)
            scene.show()

            camera_direction = scene.camera_transform[0:3, 2]
            
            best_face_index = -1
            max_dot_product = -2

            for i, face in enumerate(simplified_faces):
                dot = np.dot(face['normal'], camera_direction)
                if dot > max_dot_product:
                    max_dot_product = dot
                    best_face_index = i
            
            selected_normal = simplified_faces[best_face_index]['normal']
            final_face_map[number_to_map] = selected_normal
            
            print(f"SUCCESS: Mapped number '{number_to_map}' to face with normal {np.round(selected_normal, 3)}")
            
            # Save progress after every successful mapping
            save_progress(final_face_map)

        print("\nAll faces mapped!")
        generate_rotations(final_face_map)

    except Exception as e:
        print(f"\nAn error occurred: {e}")
        print("Please ensure 'pyglet<2' is installed and try again.")