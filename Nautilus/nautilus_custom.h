/* Return type for highlight */
struct highlight_return {
    char* r0;
    char* r1;
};

extern struct highlight_return highlight(const char* p0,const char* p1,const char* p2);

struct colors_return {
	char* fg;
	char* bg;
};

extern struct colors_return colors(const char* p0);

extern char* names();
