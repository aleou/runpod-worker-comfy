import runpod
from runpod.serverless.utils import rp_upload
import json
import urllib.request
import urllib.parse
import time
import os
import requests
import base64
from io import BytesIO

# Time to wait between API check attempts in milliseconds
COMFY_API_AVAILABLE_INTERVAL_MS = 50
# Maximum number of API check attempts
COMFY_API_AVAILABLE_MAX_RETRIES = 500
# Time to wait between poll attempts in milliseconds
COMFY_POLLING_INTERVAL_MS = int(os.environ.get("COMFY_POLLING_INTERVAL_MS", 250))
# Maximum number of poll attempts
COMFY_POLLING_MAX_RETRIES = int(os.environ.get("COMFY_POLLING_MAX_RETRIES", 500))
# Host where ComfyUI is running
COMFY_HOST = "127.0.0.1:8188"
# Enforce a clean state after each job is done
# see https://docs.runpod.io/docs/handler-additional-controls#refresh-worker
REFRESH_WORKER = os.environ.get("REFRESH_WORKER", "false").lower() == "true"


def validate_input(job_input):
    """
    Validates the input for the handler function.

    Args:
        job_input (dict): The input data to validate.

    Returns:
        tuple: A tuple containing the validated data and an error message, if any.
               The structure is (validated_data, error_message).
    """
    # Validate if job_input is provided
    if job_input is None:
        return None, "Please provide input"

    # Check if input is a string and try to parse it as JSON
    if isinstance(job_input, str):
        try:
            job_input = json.loads(job_input)
        except json.JSONDecodeError:
            return None, "Invalid JSON format in input"

    # Validate 'workflow' in input
    workflow = job_input.get("workflow")
    if workflow is None:
        return None, "Missing 'workflow' parameter"

    # Validate 'images' in input, if provided
    images = job_input.get("images")
    if images is not None:
        if not isinstance(images, list) or not all(
            "name" in image and "image" in image for image in images
        ):
            return (
                None,
                "'images' must be a list of objects with 'name' and 'image' keys",
            )

    # Validate 'files' in input, if provided (new parameter for URLs)
    files = job_input.get("files")
    if files is not None:
        if not isinstance(files, list):
            return None, "'files' must be a list"
        
        for file in files:
            if "name" not in file:
                return None, "Each file must have a 'name' field"
            if "url" not in file:
                return None, "Each file must have a 'url' field"

    # Return validated data and no error
    return {"workflow": workflow, "images": images, "files": files}, None


def check_server(url, retries=500, delay=50):
    """
    Check if a server is reachable via HTTP GET request

    Args:
    - url (str): The URL to check
    - retries (int, optional): The number of times to attempt connecting to the server. Default is 50
    - delay (int, optional): The time in milliseconds to wait between retries. Default is 500

    Returns:
    bool: True if the server is reachable within the given number of retries, otherwise False
    """

    for i in range(retries):
        try:
            response = requests.get(url)

            # If the response status code is 200, the server is up and running
            if response.status_code == 200:
                print(f"runpod-worker-comfy - API is reachable")
                return True
        except requests.RequestException as e:
            # If an exception occurs, the server may not be ready
            pass

        # Wait for the specified delay before retrying
        time.sleep(delay / 1000)

    print(
        f"runpod-worker-comfy - Failed to connect to server at {url} after {retries} attempts."
    )
    return False


def upload_images(images):
    """
    Upload a list of base64 encoded images to the ComfyUI server using the /upload/image endpoint.

    Args:
        images (list): A list of dictionaries, each containing the 'name' of the image and the 'image' as a base64 encoded string.
        server_address (str): The address of the ComfyUI server.

    Returns:
        list: A list of responses from the server for each image upload.
    """
    if not images:
        return {"status": "success", "message": "No images to upload", "details": []}

    responses = []
    upload_errors = []

    print(f"runpod-worker-comfy - image(s) upload")

    for image in images:
        name = image["name"]
        image_data = image["image"]
        blob = base64.b64decode(image_data)

        # Prepare the form data
        files = {
            "image": (name, BytesIO(blob), "image/png"),
            "overwrite": (None, "true"),
        }

        # POST request to upload the image
        response = requests.post(f"http://{COMFY_HOST}/upload/image", files=files)
        if response.status_code != 200:
            upload_errors.append(f"Error uploading {name}: {response.text}")
        else:
            responses.append(f"Successfully uploaded {name}")

    if upload_errors:
        print(f"runpod-worker-comfy - image(s) upload with errors")
        return {
            "status": "error",
            "message": "Some images failed to upload",
            "details": upload_errors,
        }

    print(f"runpod-worker-comfy - image(s) upload complete")
    return {
        "status": "success",
        "message": "All images uploaded successfully",
        "details": responses,
    }


def download_files_from_urls(files):
    """
    Download files (images/videos) from URLs and save them to the ComfyUI input folder.

    Args:
        files (list): A list of dictionaries, each containing:
                     - 'name': the filename to save as
                     - 'url': the URL to download from

    Returns:
        dict: Status and details of the download operation.
    """
    if not files:
        return {"status": "success", "message": "No files to download", "details": []}

    # ComfyUI input folder path
    COMFY_INPUT_PATH = os.environ.get("COMFY_INPUT_PATH", "/comfyui/input")
    
    # Create input directory if it doesn't exist
    os.makedirs(COMFY_INPUT_PATH, exist_ok=True)

    responses = []
    download_errors = []

    print(f"runpod-worker-comfy - downloading file(s) from URL(s)")

    for file in files:
        name = file["name"]
        url = file["url"]
        
        try:
            print(f"runpod-worker-comfy - downloading {name} from {url}")
            
            # Download the file with a timeout
            response = requests.get(url, timeout=60, stream=True)
            response.raise_for_status()
            
            # Save the file to the input folder
            file_path = os.path.join(COMFY_INPUT_PATH, name)
            
            with open(file_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk:
                        f.write(chunk)
            
            responses.append(f"Successfully downloaded {name} to {file_path}")
            print(f"runpod-worker-comfy - saved {name} to {file_path}")
            
        except requests.RequestException as e:
            error_msg = f"Error downloading {name} from {url}: {str(e)}"
            download_errors.append(error_msg)
            print(f"runpod-worker-comfy - {error_msg}")
        except Exception as e:
            error_msg = f"Error saving {name}: {str(e)}"
            download_errors.append(error_msg)
            print(f"runpod-worker-comfy - {error_msg}")

    if download_errors:
        print(f"runpod-worker-comfy - file(s) download completed with errors")
        return {
            "status": "error",
            "message": "Some files failed to download",
            "details": download_errors,
        }

    print(f"runpod-worker-comfy - file(s) download complete")
    return {
        "status": "success",
        "message": "All files downloaded successfully",
        "details": responses,
    }


def queue_workflow(workflow):
    """
    Queue a workflow to be processed by ComfyUI

    Args:
        workflow (dict): A dictionary containing the workflow to be processed

    Returns:
        dict: The JSON response from ComfyUI after processing the workflow
    """

    # The top level element "prompt" is required by ComfyUI
    data = json.dumps({"prompt": workflow}).encode("utf-8")

    req = urllib.request.Request(f"http://{COMFY_HOST}/prompt", data=data)
    return json.loads(urllib.request.urlopen(req).read())


def get_history(prompt_id):
    """
    Retrieve the history of a given prompt using its ID

    Args:
        prompt_id (str): The ID of the prompt whose history is to be retrieved

    Returns:
        dict: The history of the prompt, containing all the processing steps and results
    """
    with urllib.request.urlopen(f"http://{COMFY_HOST}/history/{prompt_id}") as response:
        return json.loads(response.read())


def base64_encode(img_path):
    """
    Returns base64 encoded image.

    Args:
        img_path (str): The path to the image

    Returns:
        str: The base64 encoded image
    """
    with open(img_path, "rb") as image_file:
        encoded_string = base64.b64encode(image_file.read()).decode("utf-8")
        return f"{encoded_string}"


def process_output_images(outputs, job_id):
    """
    Process outputs from ComfyUI workflow execution and upload to S3 or return as base64.
    
    Supports all ComfyUI output types:
    - images: Standard image outputs (PNG, JPG, WEBP)
    - gifs: Animated outputs from VHS_VideoCombine, SaveAnimatedWEBP, SaveAnimatedPNG (MP4, GIF, WEBP)
    - videos: Direct video outputs from custom nodes
    
    Args:
        outputs (dict): ComfyUI execution outputs containing node results
        job_id (str): Unique job identifier for S3 upload paths
    
    Returns:
        dict: Status, message, and files list with URLs or base64 data
    """
    COMFY_OUTPUT_PATH = os.environ.get("COMFY_OUTPUT_PATH", "/comfyui/output")
    
    output_files = []
    
    # Supported output types in ComfyUI
    OUTPUT_TYPES = ["images", "gifs", "videos"]
    
    for node_id, node_output in outputs.items():
        for output_type in OUTPUT_TYPES:
            if output_type in node_output:
                for item in node_output[output_type]:
                    # Get subfolder and filename
                    subfolder = item.get("subfolder", "")
                    filename = item.get("filename")
                    
                    if not filename:
                        print(f"runpod-worker-comfy - WARNING: missing filename in {output_type} output from node {node_id}")
                        continue
                    
                    # Build file path
                    if subfolder:
                        file_path = os.path.join(subfolder, filename)
                    else:
                        file_path = filename
                    
                    output_files.append({
                        "path": file_path,
                        "type": item.get("type", "unknown"),
                        "format": item.get("format", "unknown")
                    })
                    
                print(f"runpod-worker-comfy - found {len(node_output[output_type])} {output_type} in node {node_id}")
    
    if not output_files:
        print("runpod-worker-comfy - ERROR: no output files found in workflow results")
        return {
            "status": "error",
            "message": "No output files found in workflow results",
        }
    
    print(f"runpod-worker-comfy - processing {len(output_files)} output file(s)")
    
    # Process and upload/encode each file
    result_files = []
    use_s3 = bool(os.environ.get("BUCKET_ENDPOINT_URL"))
    bucket_name = os.environ.get("BUCKET_NAME", "")
    
    for file_info in output_files:
        file_path = file_info["path"]
        local_file_path = os.path.join(COMFY_OUTPUT_PATH, file_path)
        filename = os.path.basename(file_path)
        
        print(f"runpod-worker-comfy - processing {filename} at {local_file_path}")
        
        if not os.path.exists(local_file_path):
            error_msg = f"File not found: {local_file_path}"
            print(f"runpod-worker-comfy - ERROR: {error_msg}")
            result_files.append({
                "filename": filename,
                "error": error_msg,
                "status": "error"
            })
            continue
        
        try:
            if use_s3:
                # Upload to S3
                if bucket_name:
                    file_url = rp_upload.upload_image(job_id, local_file_path, bucket_name=bucket_name)
                else:
                    file_url = rp_upload.upload_image(job_id, local_file_path)
                result_files.append({
                    "filename": filename,
                    "url": file_url,
                    "type": file_info.get("type"),
                    "format": file_info.get("format"),
                    "status": "success"
                })
                print(f"runpod-worker-comfy - ✓ {filename} uploaded to S3{f' (bucket: {bucket_name})' if bucket_name else ''}")
            else:
                # Encode as base64
                file_base64 = base64_encode(local_file_path)
                result_files.append({
                    "filename": filename,
                    "data": file_base64,
                    "type": file_info.get("type"),
                    "format": file_info.get("format"),
                    "status": "success"
                })
                print(f"runpod-worker-comfy - ✓ {filename} encoded as base64")
                
        except Exception as e:
            error_msg = f"Failed to process {filename}: {str(e)}"
            print(f"runpod-worker-comfy - ERROR: {error_msg}")
            result_files.append({
                "filename": filename,
                "error": error_msg,
                "status": "error"
            })
    
    # Check if all files failed
    successful_files = [f for f in result_files if f.get("status") == "success"]
    
    if not successful_files:
        return {
            "status": "error",
            "message": "All output files failed to process",
            "files": result_files
        }
    
    # Return results (backward compatible with single file workflow)
    first_success = successful_files[0]
    return {
        "status": "success",
        "message": first_success.get("url") or first_success.get("data"),
        "files": result_files
    }


def handler(job):
    """
    The main function that handles a job of generating an image.

    This function validates the input, sends a prompt to ComfyUI for processing,
    polls ComfyUI for result, and retrieves generated images.

    Args:
        job (dict): A dictionary containing job details and input parameters.

    Returns:
        dict: A dictionary containing either an error message or a success status with generated images.
    """
    job_input = job["input"]

    # Make sure that the input is valid
    validated_data, error_message = validate_input(job_input)
    if error_message:
        return {"error": error_message}

    # Extract validated data
    workflow = validated_data["workflow"]
    images = validated_data.get("images")
    files = validated_data.get("files")

    # Make sure that the ComfyUI API is available
    check_server(
        f"http://{COMFY_HOST}",
        COMFY_API_AVAILABLE_MAX_RETRIES,
        COMFY_API_AVAILABLE_INTERVAL_MS,
    )

    # Download files from URLs if they exist
    if files:
        download_result = download_files_from_urls(files)
        if download_result["status"] == "error":
            return download_result

    # Upload images if they exist
    upload_result = upload_images(images)

    if upload_result["status"] == "error":
        return upload_result

    # Queue the workflow
    try:
        queued_workflow = queue_workflow(workflow)
        prompt_id = queued_workflow["prompt_id"]
        print(f"runpod-worker-comfy - queued workflow with ID {prompt_id}")
    except Exception as e:
        return {"error": f"Error queuing workflow: {str(e)}"}

    # Poll for completion
    print(f"runpod-worker-comfy - wait until image generation is complete")
    retries = 0
    try:
        while retries < COMFY_POLLING_MAX_RETRIES:
            history = get_history(prompt_id)

            # Exit the loop if we have found the history
            if prompt_id in history and history[prompt_id].get("outputs"):
                break
            else:
                # Wait before trying again
                time.sleep(COMFY_POLLING_INTERVAL_MS / 1000)
                retries += 1
        else:
            return {"error": "Max retries reached while waiting for image generation"}
    except Exception as e:
        return {"error": f"Error waiting for image generation: {str(e)}"}

    # Get the generated image and return it as URL in an AWS bucket or as base64
    images_result = process_output_images(history[prompt_id].get("outputs"), job["id"])

    result = {**images_result, "refresh_worker": REFRESH_WORKER}

    return result


# Start the handler only if this script is run directly
if __name__ == "__main__":
    runpod.serverless.start({"handler": handler})
