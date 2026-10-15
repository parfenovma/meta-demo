// P1 triangle interpolation shared by harmonic, transient and workbench views.
// Coordinates/transforms are supplied by the caller; no physics is inferred.
function triangleWeights(xy, triangles, width, height, X, Y) {
    const W = Math.ceil(width), H = Math.ceil(height), size = W * H;
    const a = new Int32Array(size).fill(-1), b = new Int32Array(size);
    const d = new Int32Array(size), u = new Float32Array(size), v = new Float32Array(size);
    for (const ids of triangles) {
        const points = ids.map(i => [X(xy[i][0]), Y(xy[i][1])]);
        const [ax, ay] = points[0];
        const bx = points[1][0] - ax, by = points[1][1] - ay;
        const dx = points[2][0] - ax, dy = points[2][1] - ay;
        const determinant = bx * dy - by * dx;
        if (Math.abs(determinant) < 1e-20) continue;
        const xmin = Math.max(0, Math.floor(Math.min(...points.map(p => p[0]))));
        const xmax = Math.min(W - 1, Math.ceil(Math.max(...points.map(p => p[0]))));
        const ymin = Math.max(0, Math.floor(Math.min(...points.map(p => p[1]))));
        const ymax = Math.min(H - 1, Math.ceil(Math.max(...points.map(p => p[1]))));
        for (let y = ymin; y <= ymax; y++) for (let x = xmin; x <= xmax; x++) {
            const px = x + .5 - ax, py = y + .5 - ay;
            const s = (px * dy - py * dx) / determinant;
            const t = (bx * py - by * px) / determinant;
            if (s >= -1e-6 && t >= -1e-6 && s + t <= 1.000001) {
                const j = y * W + x;
                a[j] = ids[0]; b[j] = ids[1]; d[j] = ids[2]; u[j] = s; v[j] = t;
            }
        }
    }
    return {w: W, h: H, a, b, d, u, v};
}

function makeTriangleRaster(field, width, height, X, Y) {
    const raster = triangleWeights(field.xy, field.tri, width, height, X, Y);
    const off = document.createElement('canvas');
    off.width = raster.w; off.height = raster.h;
    const oc = off.getContext('2d');
    return {...raster, off, oc, image: oc.createImageData(raster.w, raster.h)};
}
