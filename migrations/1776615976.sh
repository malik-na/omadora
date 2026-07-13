echo "Install missing Intel VPL drivers (libvpl, vpl-gpu-rt) on systems with Intel GPUs"

# Apple Silicon has no Intel GPU, so this fork ships no intel/video-acceleration.sh. Without the
# guard the migration would call a script that does not exist and fail the whole migration run.
VIDEO_ACCELERATION="$OMARCHY_PATH/install/config/hardware/intel/video-acceleration.sh"

if [[ -f $VIDEO_ACCELERATION ]]; then
  bash "$VIDEO_ACCELERATION"
fi
