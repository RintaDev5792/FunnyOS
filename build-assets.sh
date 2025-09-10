#!/bin/bash

set -e

build_widget() {
    local widget_dir="$1"
    local widget_name="$2"

    echo "$widget_dir"
    pdc "$widget_dir" "Assets/Widgets/${widget_name}.pdx"
    if [ ! -f "Assets/Widgets/${widget_name}.pdx/installpath" ]; then
        echo "/Shared/FunnyOS2/Widgets/${widget_name}.pdx/" > "Assets/Widgets/${widget_name}.pdx/installpath"
    fi

    if [ -f "Assets/Widgets/${widget_name}.pdx.zip" ]; then
        rm "Assets/Widgets/${widget_name}.pdx.zip"
    fi
    cd "Assets/Widgets"
    zip -r "${widget_name}.pdx.zip" "${widget_name}.pdx/"
    rm -r "${widget_name}.pdx/"
    cd -
}

build_widget "Widgets/FunnyLoader" "FunnyLoader"
build_widget "Widgets/To-Do List" "Todo"
build_widget "Widgets/Badge Downloader" "BadgeDownloader"
build_widget "Widgets/Package Downloader" "PackageDownloader"
build_widget "Widgets/File Explorer" "FileExplorer"