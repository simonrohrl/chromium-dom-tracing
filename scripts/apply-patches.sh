echo "Applying patches..."
for f in ../patches/*.patch; do
    if [ -f "$f" ]; then
        echo "Applying $f"
        git apply "$f"
    fi
done

echo "Successfully applied patches"