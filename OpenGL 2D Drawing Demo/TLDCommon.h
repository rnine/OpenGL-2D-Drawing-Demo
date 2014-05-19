// Custom logger
#ifdef DEBUG
#   define DLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ## __VA_ARGS__);
#else
#   define DLog(...)
#endif

// ALog always displays output regardless of the DEBUG setting
#define ALog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ## __VA_ARGS__);

#if defined(__STRICT_ANSI__)
struct _TLDMatrix4
{
    float m[16];
} __attribute__((aligned(16)));
typedef struct _TLDMatrix4 TLDMatrix4;
#else
union _TLDMatrix4
{
    struct
    {
        float m00, m01, m02, m03;
        float m10, m11, m12, m13;
        float m20, m21, m22, m23;
        float m30, m31, m32, m33;
    };
    float m[16];
} __attribute__((aligned(16)));
typedef union _TLDMatrix4 TLDMatrix4;
#endif

static inline TLDMatrix4 TLDMatrix4MakeOrtho(float left, float right,
                                             float bottom, float top,
                                             float nearZ, float farZ)
{
    float ral = right + left;
    float rsl = right - left;
    float tab = top + bottom;
    float tsb = top - bottom;
    float fan = farZ + nearZ;
    float fsn = farZ - nearZ;

    TLDMatrix4 m = { {2.0f / rsl, 0.0f, 0.0f, 0.0f,
                      0.0f, 2.0f / tsb, 0.0f, 0.0f,
                      0.0f, 0.0f, -2.0f / fsn, 0.0f,
                      -ral / rsl, -tab / tsb, -fan / fsn, 1.0f} };

    return m;
}
