file="$1"
basename="$(basename "$file")"
stem="${basename%.*}"
outdir="/tmp"
outfile="$outdir/$stem.pdf"

if [ ! -f "$outfile" ]; then
  libreoffice --headless --convert-to pdf "$file" --outdir "$outdir"
fi

# Render first page to PNG
pdftoppm -png -f 1 -singlefile "$outfile" | image
