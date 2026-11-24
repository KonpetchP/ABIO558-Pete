//==================================================
// Job name            step2_KymographBuilder.ijm
// Running software    Fiji Macros
// Author              Pattanai Konpetch
// Description         Reslice and z-project cilia movie to get kymograph
// Year/Month/Date     2026/11/21
// Update              2026/11/21                                                                    
// Update description
// 2026/11/21 : loop over movie folders in cilia_strip/, save kymographs per movie                  
//===================================================

// Set up working directory
project = "/Users/pattanaikonpetch/Desktop/ABIO558_miniproject/";
input  = project + "cilia_strip/";
output = project + "kymographs/";
// REMOVED: coordinate file (not used in this step)
if (!File.exists(output)) File.makeDirectory(output);

// List all movie folders in input directory (movie_1/, movie_2/, ...)                              
movieFolders = getFileList(input);

// Process image without showing image on screen
setBatchMode(true);

// Calibration settings
pixelSize = 0.1833333;																	// µm per pixel
frameTime = 0.05;         																// seconds per frame

//---------------------------------------------------
// Start movie folder loop
for (m = 0; m < movieFolders.length; m++) {
	if (!endsWith(movieFolders[m], "/")) continue;                                     // only folders
	folder = input + movieFolders[m];                                                  // e.g. cilia_strip/movie_1/
	movieName = substring(movieFolders[m], 0, lengthOf(movieFolders[m]) - 1);          // "movie_1/" -> "movie_1"
	movieDir = output + movieName + File.separator;                                    // e.g. kymographs/movie_1/
	if (!File.exists(movieDir)) File.makeDirectory(movieDir);
	list = getFileList(folder);
	print("Movie folder: " + folder + "  (" + list.length + " items)");

	//---------------------------------------------------
	// Start strip loop
	for (i = 0; i < list.length; i++) {
    	if (!endsWith(toLowerCase(list[i]), ".tif")) continue;
    	print("Found: " + folder + list[i]);                                           

    	// find basename
    	base = substring(list[i], 0, lastIndexOf(list[i], "."));
    	// REMOVED: movieDir per strip (movieDir is set per movie above)

    	// Open the cilium strip (.tif)                                                 
    	run("Bio-Formats Importer", "open=[" + folder + list[i] + "] color_mode=Grayscale view=Hyperstack stack_order=XYCZT");   // CHANGED: input -> folder
    	movie = getTitle();
    	getDimensions(width, height, channels, slices, frames);
    	print("  opened: " + movie + "  " + width + " x " + height + ", frames: " + frames);

    	// Tell Fiji the time points are slices, so Reslice turns them into the Y axis
    	run("Properties...", "channels=1 slices=" + (slices*frames) + " frames=1");

    	// Reslice
    	run("Reslice [/]...", "start=Top avoid");                                    

    	// Z-projection (Max Intensity)
    	run("Z Project...", "projection=[Max Intensity]");

    	// Edit file properties of the kymograph: X = µm along the cilium, Y = seconds
    	run("Properties...", "channels=1 slices=1 frames=1 pixel_width=" + pixelSize + " pixel_height=" + frameTime + " voxel_depth=1");

    	// Save file
    	saveAs("Tiff", movieDir + base + "_kymograph.tif");                            // e.g. kymographs/movie_1/movie_1_cilia_1_kymograph.tif
    	print("    saved: " + base + "_kymograph.tif");

    	close("*");                                                                    // close this strip's images
	}                                                         
}                                                         

setBatchMode(false);
print("Done");
