#!/bin/bash

set -e

build_widget() {
    local widget_dir="$1"
    local widget_name="$2"

    echo "$widget_dir"
    pdc "$widget_dir" "Assets/Widgets/${widget_name}.pdx"
    echo "/Shared/FunnyOS/Widgets/${widget_name}.pdx/" > "Assets/Widgets/${widget_name}.pdx/installpath"

    if [ -f "Assets/Widgets/${widget_name}.pdx.zip" ]; then
        rm "Assets/Widgets/${widget_name}.pdx.zip"
    fi
    zip -r "Assets/Widgets/${widget_name}.pdx.zip" "Assets/Widgets/${widget_name}.pdx/"
    rm -r "Assets/Widgets/${widget_name}.pdx/"
}

build_widget "Widgets/FunnyLoader" "FunnyLoader"
build_widget "Widgets/To-Do List" "Todo"
build_widget "Widgets/Badge Downloader" "BadgeDownloader"
build_widget "Widgets/Package Downloader" "PackageDownloader"