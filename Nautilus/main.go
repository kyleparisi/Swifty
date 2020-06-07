package main

import (
	"C"
	"bytes"
	"fmt"
	"regexp"

	"github.com/alecthomas/chroma"
	"github.com/alecthomas/chroma/formatters/html"
	"github.com/alecthomas/chroma/lexers"
	"github.com/alecthomas/chroma/styles"
)

type preWrapper struct {
	start func(code bool, styleAttr string) string
	end   func(code bool) string
}

func (p preWrapper) Start(code bool, styleAttr string) string {
	return p.start(code, styleAttr)
}

func (p preWrapper) End(code bool) string {
	return p.end(code)
}

//export highlight
func highlight(c_source, c_lexer, c_style *C.char) (*C.char, *C.char) {

	source := C.GoString(c_source)
	lexer := C.GoString(c_lexer)
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

	// Formatter.
	var wrapper = preWrapper{
		start: func(code bool, styleAttr string) string {
			return fmt.Sprintf("<pre%s>\n", styleAttr)
		},
		end: func(code bool) string {
			return "</pre>"
		},
	}
	f := html.New(html.WithPreWrapper(wrapper))

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

//export colors
func colors(c_style *C.char) (*C.char, *C.char) {
	s := styles.Get(C.GoString(c_style))
	colors := s.Get(chroma.Background)
	bgr, _ := regexp.Compile("bg:(#.*)")
	bgmatch := bgr.FindStringSubmatch(colors.String())
	fmt.Print(bgmatch)
	fgr, _ := regexp.Compile("(#.*) bg:")
	fgmatch := fgr.FindStringSubmatch(colors.String())
	fg := ""
	if len(fgmatch) == 0 {
		fg = "#000000"
	} else {
		fg = fgmatch[1]	
	}
	return C.CString(fg), C.CString(bgmatch[1])
}

// We need an entry point; it's ok for this to be empty
func main() {}
