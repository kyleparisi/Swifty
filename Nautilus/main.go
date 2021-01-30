package main

import (
	"C"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"regexp"
	"strings"

	"github.com/alecthomas/chroma"
	"github.com/alecthomas/chroma/formatters"
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

	type MyStyleEntry struct {
		// Hex colours.
		Color      chroma.Colour `json:"color"`
		Background chroma.Colour `json:"bg"`
		Border     chroma.Colour `json:"br"`

		Bold      chroma.Trilean `json:"bold"`
		Italic    chroma.Trilean `json:"italic"`
		Underline chroma.Trilean `json:"underline"`
		NoInherit bool           `json:"noinherit"`
	}

	type MyToken struct {
		Type  chroma.TokenType `json:"type"`
		Value string           `json:"value"`
		Style MyStyleEntry     `json:"style"`
	}

	// Formatter.
	formatters.Register("json_styled", chroma.FormatterFunc(func(w io.Writer, s *chroma.Style, it chroma.Iterator) error {
		fmt.Fprintln(w, "[")
		i := 0
		for t := it(); t != chroma.EOF; t = it() {
			if i > 0 {
				fmt.Fprintln(w, ",")
			}
			style := s.Get(t.Type)
			mytoken := MyToken{
				Type:  t.Type,
				Value: t.Value,
				Style: MyStyleEntry{
					Color:      style.Colour,
					Background: style.Background,
					Border:     style.Border,
					Bold:       style.Bold,
					Italic:     style.Italic,
					Underline:  style.Underline,
					NoInherit:  style.NoInherit,
				},
			}
			i++
			bytes, err := json.Marshal(mytoken)
			if err != nil {
				return err
			}
			if _, err := fmt.Fprint(w, "  "+string(bytes)); err != nil {
				return err
			}
		}
		fmt.Fprintln(w)
		fmt.Fprintln(w, "]")
		return nil
	}))
	f := formatters.Get("json_styled")

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
	// fmt.Print(bgmatch)
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

//export names
func names() *C.char {
    output := lexers.Names(false)
    return C.CString(strings.Join(output[:], ","))
}

// We need an entry point; it's ok for this to be empty
func main() {}
