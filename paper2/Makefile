# Makefile for EVMAuth Paper 2

.PHONY: all clean pdf view

# Main target
all: pdf

# Build PDF
pdf:
	pdflatex main.tex
	bibtex main
	pdflatex main.tex
	pdflatex main.tex

# Clean auxiliary files
clean:
	rm -f *.aux *.bbl *.blg *.log *.out *.toc *.lof *.lot *.fls *.fdb_latexmk *.synctex.gz
	rm -f sections/*.aux

# Clean everything including PDF
cleanall: clean
	rm -f main.pdf

# View PDF (macOS)
view: pdf
	open main.pdf

# Quick build (single pass, for drafting)
draft:
	pdflatex main.tex
