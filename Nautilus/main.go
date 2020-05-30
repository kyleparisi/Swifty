package main

import (
	"C"
	"bytes"

	"github.com/alecthomas/chroma"
	"github.com/alecthomas/chroma/formatters"
	"github.com/alecthomas/chroma/lexers"
	"github.com/alecthomas/chroma/styles"
)

//export highlight
func highlight(c_source, c_lexer, c_formatter, c_style *C.char) (*C.char, *C.char) {

	source := C.GoString(c_source)
	lexer := C.GoString(c_lexer)
	formatter := C.GoString(c_formatter)
	style := C.GoString(c_style)

	// Determine lexer.
	l := lexers.Get(lexer)
	if l == nil {
		l = lexers.Analyse(source)
	}
	if l == nil {
		l = lexers.Fallback
	}
	l = chroma.Coalesce(l)

	// Determine formatter.
	f := formatters.Get(formatter)
	if f == nil {
		f = formatters.Fallback
	}

	// Determine style.
	s := styles.Get(style)
	if s == nil {
		s = styles.Fallback
	}

	it, err := l.Tokenise(nil, source)
	if err != nil {
		return C.CString(""), C.CString(err.Error())
	}

	var buf bytes.Buffer
	err = f.Format(&buf, s, it)
	if err != nil {
		return C.CString(""), C.CString(err.Error())
	}
	return C.CString(buf.String()), C.CString("")

}

// We need an entry point; it's ok for this to be empty
func main() {}
