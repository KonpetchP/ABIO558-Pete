
//==================================================
// Job name            step1_PreProcessedMovie_MakeCiliumStrip.ijm
// Running software    Fiji Macros
// Author              Pattanai Konpetch
// Description         Pre-process 2D timelapse movie of cilia, make separate cilia into individual movie
// Year/Month/Date     2026/11/16
// Update              2026/11/21                                                                    
// Update description
// 2026/11/18 : setting up the cropped square region
// 2026/11/20 : cilium loop, edge check, canvas resize, rotation, strip crop and save
// 2026/11/21 : strip size calculated per cilium from its shape (halfL, halfW)                       
//===================================================

// Set up working directory
project = "/Users/pattanaikonpetch/Desktop/ABIO558_miniproject/";
input  = project + "movies/";
output = project + "cilia_strip/";
coordinate = project + "ciliaCoordinate.csv";
if (!File.exists(output)) File.makeDirectory(output);

// List all input file in input directory
list = getFileList(input);

// Load coordinate file
Table.open(coordinate);
coTable = Table.title;
nRows = Table.size;

// Define a padding size
canvasPad = 50;											// extra px added on every side of the duplicated square, giving room for the rotation

// Strip crop setting (used after rotation)
margin = 10;											// extra px beyond base and tip                 
pad = 15;											// extra px on each side of the cilium path     

// Process image without showing image on screen
setBatchMode(true);

//---------------------------------------------------
// Start loop
for (i = 0; i < list.length; i++) {
    if (!endsWith(toLowerCase(list[i]), ".nd2")) continue;
    print("Found: " + input + list[i]);

    // find basename and set output directory
    base = substring(list[i], 0, lastIndexOf(list[i], "."));
    movieDir = output + base + File.separator;
    if (!File.exists(movieDir)) File.makeDirectory(movieDir);

    // Open the .nd2 movie with Bio-Formats
    run("Bio-Formats Importer", "open=[" + input + list[i] + "] color_mode=Grayscale view=Hyperstack stack_order=XYCZT");
    movie = getTitle();
    getDimensions(width, height, channels, slices, frames);
    print("  opened: " + movie + "  " + width + " x " + height + ", frames: " + frames);

    // Bleach Correction
    run("Bleach Correction", "correction=[Histogram Matching]");
    corrected = getTitle();
    close(movie);
    selectImage(corrected);

    // Despeckle
    run("Despeckle", "stack");

    // Background and contrast
    setMinAndMax(120, 200);
    run("Apply LUT", "stack");

    // Find how many cilia this movie has in the coordinate file
    nCilia = 0;
    for (r = 0; r < nRows; r++) {
        if (Table.getString("movie", r, coTable) == base) nCilia = maxOf(nCilia, Table.get("cilium", r, coTable));
    }
    print("  cilia in coordinate file: " + nCilia);

    //---------------------------------------------------
    // Start cilium loop
    for (k = 1; k <= nCilia; k++) {

        // Calculate cropped square region
        // Find point of each table row
        xs = newArray(0);
        ys = newArray(0);
        // Get coordinate list from ciliaCoordinate.csv
        for (r = 0; r < nRows; r++) {
            if (Table.getString("movie", r, coTable) == base &&					// crosscheck that you are on a correct movie
                Table.get("cilium", r, coTable) == k) {        					// crosscheck for cilium that you work with
                xs = Array.concat(xs, Table.get("x", r, coTable)); 				// read x coordinate
                ys = Array.concat(ys, Table.get("y", r, coTable)); 				// read y coordinate
            }
        }

        // Find Maximum and minimum coordinate for square size calculation
        Array.getStatistics(xs, xMin, xMax); // get maximum/minimum value in X
        Array.getStatistics(ys, yMin, yMax); // get maximum/minimum value in Y
        // Calculate square size
        rangeX = xMax - xMin;
        rangeY = yMax - yMin;
        // Mark a center body of the square
        cx = round(xMin + rangeX / 2); // set a central body in X axis
        cy = round(yMin + rangeY / 2); // set a central body in Y axis
        // Calculate a half/full of 1.5 times distance away from cx and cy
        half = round(0.75 * maxOf(rangeX, rangeY));                                            // half of the cropped size with 1.5 time from actual full size square     
        roomHalf = minOf(minOf(cx, width - cx), minOf(cy, height - cy));                       // biggest half that fits inside the original movie size
        half = minOf(half, roomHalf);                                                          // shrink only if near the edge
        if (half < maxOf(rangeX, rangeY) / 2) {                                                // cilium must still fit in the square
            print("  SKIPPED cilium " + k + ": too close to the edge");
            continue;
        }
        full = 2 * half;

        // Draw the square cropped box
        // makeRectangle(x, y, width, height) : This command make square out from upper left corner coordinate
        UpperLeft_x = cx - half;
        UpperLeft_y = cy - half;
        selectImage(corrected);
        makeRectangle(UpperLeft_x, UpperLeft_y, full, full);

        // Duplicate a square
        ciliaName = base + "_cilia_" + k;
        run("Duplicate...", "title=" + ciliaName + " duplicate");
        run("Select None");
        square = getTitle();

        // Resize canvas
        newSize = full + 2*canvasPad;
        run("Canvas Size...", "width=" + newSize + " height=" + newSize + " position=Center zero");

        // Rotation
        // Calculate ciliary angle
        // Load coordinate of first (base) and last (tip) point
        baseX = xs[0];
        baseY = ys[0];
        tipX  = xs[xs.length - 1];
        tipY  = ys[ys.length - 1];
        // Calculate ciliary angle by using trigonometry: tan(θ) = -dy / dx                                                          
        dx = tipX - baseX;
        dy = tipY - baseY;
        ciliary_angle = atan2(-dy, dx);                                                        // "atan2" give angle value in radians while still keep the sign
        // Convert angle to degrees for Rotate
        rotatation_angle = ciliary_angle * 180 / PI;                                           // * 180 / π to convert from radians to degree unit
        // Rotate the square so the tip is on the right ("Rotate... " with a space = rotate the image)
        selectImage(square);
        run("Rotate... ", "angle=" + rotatation_angle + " grid=1 interpolation=Bilinear stack");
        print("  cilium " + k + ": centre (" + cx + ", " + cy + ")  half " + half + "  angle " + d2s(rotatation_angle, 1));

        // Make cropped cilium strip
        // Calculate cilia length by Pythagoras: A^2 + B^2 = C^2
        ciliary_length = sqrt(dx*dx + dy*dy);
        // Calculate vector of cilium directionality in X and Y per 1-pixel step along the cilium (base to tip)
        ux = dx / ciliary_length;
        uy = dy / ciliary_length;
        // Calculate where the square centre lands after rotation
        new_cx = (cx - baseX)*ux + (cy - baseY)*uy;						// how many steps along the cilium the centre is
        new_cy = -(cx - baseX)*uy + (cy - baseY)*ux;                       			// how far the centre is off the base-tip line

        // Find the furthest point from the centre, along and across the cilium
        halfL = 0;
        halfW = 0;
        for (p = 0; p < xs.length; p++) {
            point_rotated_dx = (xs[p] - baseX)*ux + (ys[p] - baseY)*uy;
            point_rotated_dy = -(xs[p] - baseX)*uy + (ys[p] - baseY)*ux;
            halfL = maxOf(halfL, abs(point_rotated_dx - new_cx));
            halfW = maxOf(halfW, abs(point_rotated_dy - new_cy));
        }

        // Calculate strip size
        stripL = minOf(round(2*halfL + 2*margin), newSize);                			 // length + margin at each end
        stripW = minOf(round(2*halfW + 2*pad), newSize);                   			 // bend + pad on each side

        // Mark a new rectangle around the centre of the rotated square
        new_UpperLeft_dx = round(newSize/2 - stripL/2);
        new_UpperLeft_dy = round(newSize/2 - stripW/2);
        selectImage(square);
        makeRectangle(new_UpperLeft_dx, new_UpperLeft_dy, stripL, stripW);

        // Cut out the strip (all frames) and save it
        run("Duplicate...", "title=strip duplicate");                      			// make the strip its own image
        saveAs("Tiff", movieDir + ciliaName + ".tif");
        close();
        close(square);
        print("    saved: " + ciliaName + ".tif (" + stripL + " x " + stripW + ")");

    }   // end of cilium loop                                                                    

    close("*");
}

setBatchMode(false);
print("Done");
