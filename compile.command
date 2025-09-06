if [ -z "$PLAYDATE_SDK_PATH" ] || [ ! -d "$PLAYDATE_SDK_PATH" ]; then
    echo "Error: PLAYDATE_SDK_PATH is not defined or does not exist."
    exit 1
fi

set -e
make device simulator
pdc ./Source $PLAYDATE_SDK_PATH/Disk/System/Launchers/FunnyOS.pdx
mkdir -p $PLAYDATE_SDK_PATH/Disk/Shared/FunnyOS2/Widgets/
for dir in Widgets/*; do
    if [ -d "$dir" ]; then
        if [ "$(basename "$dir")" != "Template" ]; then
            pdc "$dir" "$PLAYDATE_SDK_PATH/Disk/Shared/FunnyOS2/Widgets/$(basename "$dir").pdx"
        fi
    fi
done
exit 0