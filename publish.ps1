quarto render --to html
if ($LASTEXITCODE -eq 0) {
    quarto publish gh-pages --no-render
}