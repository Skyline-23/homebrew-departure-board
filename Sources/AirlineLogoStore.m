#import "AirlineLogoStore.h"
#import "DepartureBoardView.h"

static NSString *NormalizedName(NSString *name) {
    NSString *folded = [(name ?: @"") stringByFoldingWithOptions:NSDiacriticInsensitiveSearch
                                                       locale:[NSLocale localeWithLocaleIdentifier:@"en"]];
    return [[[folded lowercaseString] componentsSeparatedByCharactersInSet:
             NSCharacterSet.alphanumericCharacterSet.invertedSet] componentsJoinedByString:@""];
}

static BOOL IsWhite(const unsigned char *pixel) {
    return pixel[3] >= 240 && MIN(pixel[0], MIN(pixel[1], pixel[2])) >= 240;
}

static NSImage *PreparedLogo(NSData *data) {
    NSBitmapImageRep *source = [[NSBitmapImageRep alloc] initWithData:data];
    CGImageRef image = source.CGImage;
    if (!image)
        return nil;
    size_t width = CGImageGetWidth(image), height = CGImageGetHeight(image);
    if (!width || !height || width > 2048 || height > 2048)
        return nil;
    size_t count = width * height;
    NSMutableData *rgba = [NSMutableData dataWithLength:count * 4];
    unsigned char *pixels = rgba.mutableBytes;
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(pixels, width, height, 8, width * 4, space,
                                                kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    if (!context)
        return nil;
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);

    // Some sources contain a white matte. Remove only edge-connected white
    // when the border is predominantly white; preserve enclosed white artwork
    // and transparent logos containing white lettering.
    size_t edgeCount = 0, whiteCount = 0;
    for (size_t y = 0; y < height; y++) {
        for (size_t x = 0; x < width; x++) {
            if (x && y && x + 1 < width && y + 1 < height)
                continue;
            edgeCount++;
            whiteCount += IsWhite(pixels + (y * width + x) * 4);
        }
    }
    if (whiteCount * 4 >= edgeCount * 3) {
        NSMutableData *storage = [NSMutableData dataWithLength:count * sizeof(size_t)];
        size_t *queue = storage.mutableBytes, head = 0, tail = 0;
        for (size_t y = 0; y < height; y++) {
            for (size_t x = 0; x < width; x++) {
                size_t index = y * width + x;
                if ((x == 0 || y == 0 || x + 1 == width || y + 1 == height) &&
                    IsWhite(pixels + index * 4)) {
                    memset(pixels + index * 4, 0, 4);
                    queue[tail++] = index;
                }
            }
        }
        while (head < tail) {
            size_t index = queue[head++], x = index % width, y = index / width;
            size_t neighbors[] = {x ? index - 1 : index, x + 1 < width ? index + 1 : index,
                                  y ? index - width : index, y + 1 < height ? index + width : index};
            for (NSUInteger side = 0; side < 4; side++) {
                size_t next = neighbors[side];
                if (IsWhite(pixels + next * 4)) {
                    memset(pixels + next * 4, 0, 4);
                    queue[tail++] = next;
                }
            }
        }
    }
    size_t left = width, top = height, right = 0, bottom = 0;
    for (size_t y = 0; y < height; y++) {
        for (size_t x = 0; x < width; x++) {
            if (pixels[(y * width + x) * 4 + 3] <= 8)
                continue;
            left = MIN(left, x); right = MAX(right, x);
            top = MIN(top, y); bottom = MAX(bottom, y);
        }
    }
    NSImage *result = nil;
    if (left < width && top < height) {
        CGImageRef rendered = CGBitmapContextCreateImage(context);
        CGImageRef cropped = CGImageCreateWithImageInRect(rendered,
            CGRectMake(left, top, right - left + 1, bottom - top + 1));
        result = [[NSImage alloc] initWithCGImage:cropped size:NSZeroSize];
        CGImageRelease(cropped);
        CGImageRelease(rendered);
    }
    CGContextRelease(context);
    return result;
}

@implementation DBAirlineLogoStore
+ (NSImage *)imageForCarrier:(NSString *)iata icao:(NSString *)icao name:(NSString *)name {
    static NSDictionary *catalog;
    static NSCache *images;
    static dispatch_once_t once;
    NSBundle *bundle = [NSBundle bundleForClass:DBBoardView.class];
    dispatch_once(&once, ^{
        NSURL *url = [bundle URLForResource:@"Catalog" withExtension:@"json" subdirectory:@"AirlineLogos"];
        NSData *data = url ? [NSData dataWithContentsOfURL:url] : nil;
        catalog = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : @{};
        images = NSCache.new;
        images.countLimit = 128;
        images.totalCostLimit = 4 * 1024 * 1024;
    });
    iata = iata.uppercaseString ?: @"";
    icao = icao.uppercaseString ?: @"";
    NSString *asset = icao.length == 3 ? icao : nil;
    NSArray *candidates = catalog[iata];
    if (!asset) {
        NSString *normalized = NormalizedName(name);
        for (NSDictionary *candidate in candidates) {
            if (normalized.length && [NormalizedName(candidate[@"name"]) isEqual:normalized]) {
                asset = candidate[@"icao"];
                break;
            }
        }
        if (!asset && candidates.count == 1)
            asset = candidates.firstObject[@"icao"];
        // For ambiguous IATA codes, the IATA-specific asset is safer than
        // choosing an unrelated airline sharing that code.
        asset = asset ?: iata;
    }
    if (!asset.length || [asset rangeOfCharacterFromSet:
                         NSCharacterSet.alphanumericCharacterSet.invertedSet].location != NSNotFound)
        return nil;
    id cached = [images objectForKey:asset];
    if (cached)
        return cached == NSNull.null ? nil : cached;
    NSURL *url = [bundle URLForResource:asset withExtension:@"png" subdirectory:@"AirlineLogos"];
    if (!url && ![asset isEqual:iata])
        url = [bundle URLForResource:iata withExtension:@"png" subdirectory:@"AirlineLogos"];
    NSImage *logo = url ? PreparedLogo([NSData dataWithContentsOfURL:url]) : nil;
    [images setObject:logo ?: NSNull.null forKey:asset
                cost:logo ? (NSUInteger)(logo.size.width * logo.size.height * 4) : 1];
    return logo;
}
@end
