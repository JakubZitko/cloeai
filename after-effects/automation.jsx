/*
 * After Effects Automation Script
 * Creates SaaS video animations based on AI analysis
 */

// Main function
function createSaaSVideo(config) {
    app.beginUndoGroup("Create SaaS Video");

    try {
        // Parse config
        var projectName = config.projectName || "SaaS Video Project";
        var duration = config.duration || 60; // seconds
        var width = config.width || 1920;
        var height = config.height || 1080;
        var frameRate = config.frameRate || 30;

        $.writeln("🎬 Creating project: " + projectName);

        // Create new project
        var project = app.project;
        project.close(CloseOptions.DO_NOT_SAVE_CHANGES);

        // Create composition
        var comp = project.items.addComp(
            projectName,
            width,
            height,
            1.0,  // Pixel aspect ratio
            duration,
            frameRate
        );

        $.writeln("✅ Composition created: " + width + "x" + height);

        // Import original video if provided
        if (config.originalVideoPath) {
            importVideo(comp, config.originalVideoPath);
        }

        // Import reference footage if provided
        if (config.referenceVideos && config.referenceVideos.length > 0) {
            for (var i = 0; i < config.referenceVideos.length; i++) {
                importReferenceFootage(comp, config.referenceVideos[i], i);
            }
        }

        // Create animations based on analysis
        if (config.animations) {
            createAnimations(comp, config.animations);
        }

        // Add text overlays
        if (config.textOverlays) {
            createTextOverlays(comp, config.textOverlays);
        }

        // Apply color grading
        if (config.colorPalette) {
            applyColorGrading(comp, config.colorPalette);
        }

        // Save project
        var projectPath = config.outputProjectPath || (config.outputDir + "/" + projectName + ".aep");
        var projectFile = new File(projectPath);
        project.save(projectFile);

        $.writeln("✅ Project saved: " + projectPath);

        // Add to render queue if requested
        if (config.autoRender) {
            addToRenderQueue(comp, config.outputVideoPath);
        }

        $.writeln("🎉 Project creation complete!");

        return {
            success: true,
            projectPath: projectPath,
            compName: comp.name
        };

    } catch (e) {
        $.writeln("❌ Error: " + e.toString());
        return {
            success: false,
            error: e.toString()
        };
    } finally {
        app.endUndoGroup();
    }
}

// Import video footage
function importVideo(comp, videoPath) {
    try {
        var importOptions = new ImportOptions(File(videoPath));
        var footage = app.project.importFile(importOptions);

        var layer = comp.layers.add(footage);
        layer.name = "Original Video";

        // Fit to comp
        layer.scale.setValue([
            (comp.width / footage.width) * 100,
            (comp.height / footage.height) * 100
        ]);

        $.writeln("✅ Video imported: " + videoPath);

        return layer;

    } catch (e) {
        $.writeln("❌ Import error: " + e.toString());
        return null;
    }
}

// Import reference footage
function importReferenceFootage(comp, refConfig, index) {
    try {
        var importOptions = new ImportOptions(File(refConfig.path));
        var footage = app.project.importFile(importOptions);

        var layer = comp.layers.add(footage);
        layer.name = "Reference " + (index + 1);

        // Position at specific time
        var startTime = refConfig.startTime || (index * 5); // 5 second intervals
        layer.startTime = startTime;

        // Trim duration if needed
        if (refConfig.duration) {
            layer.outPoint = startTime + refConfig.duration;
        }

        // Apply opacity if specified
        if (refConfig.opacity) {
            layer.opacity.setValue(refConfig.opacity);
        }

        $.writeln("✅ Reference footage added: " + refConfig.path);

        return layer;

    } catch (e) {
        $.writeln("❌ Reference import error: " + e.toString());
        return null;
    }
}

// Create animations
function createAnimations(comp, animations) {
    $.writeln("🎨 Creating " + animations.length + " animations");

    for (var i = 0; i < animations.length; i++) {
        var anim = animations[i];

        switch (anim.type) {
            case "logo_reveal":
                createLogoReveal(comp, anim);
                break;
            case "feature_showcase":
                createFeatureShowcase(comp, anim);
                break;
            case "text_animation":
                createTextAnimation(comp, anim);
                break;
            case "transition":
                createTransition(comp, anim);
                break;
            default:
                $.writeln("⚠️  Unknown animation type: " + anim.type);
        }
    }
}

// Logo reveal animation
function createLogoReveal(comp, config) {
    // Create solid layer for logo background
    var bgLayer = comp.layers.addSolid(
        [0, 0, 0],
        "Logo BG",
        comp.width,
        comp.height,
        1.0
    );

    bgLayer.startTime = config.startTime || 0;
    bgLayer.outPoint = (config.startTime || 0) + (config.duration || 3);

    // Animate opacity
    bgLayer.opacity.setValueAtTime(config.startTime || 0, 0);
    bgLayer.opacity.setValueAtTime((config.startTime || 0) + 0.5, 100);
    bgLayer.opacity.setValueAtTime((config.startTime || 0) + (config.duration || 3) - 0.5, 100);
    bgLayer.opacity.setValueAtTime((config.startTime || 0) + (config.duration || 3), 0);

    $.writeln("✅ Logo reveal created");
}

// Feature showcase animation
function createFeatureShowcase(comp, config) {
    // TODO: Implement feature showcase
    $.writeln("ℹ️  Feature showcase animation (placeholder)");
}

// Text animation
function createTextAnimation(comp, config) {
    var textLayer = comp.layers.addText(config.text || "Sample Text");
    var textProp = textLayer.property("Source Text");
    var textDocument = textProp.value;

    // Configure text
    textDocument.fontSize = config.fontSize || 72;
    textDocument.fillColor = hexToRgb(config.color || "#FFFFFF");
    textDocument.font = config.font || "Helvetica Neue";
    textDocument.justification = ParagraphJustification.CENTER_JUSTIFY;

    textProp.setValue(textDocument);

    // Position
    var startTime = config.startTime || 0;
    textLayer.startTime = startTime;

    // Animate position (slide in from top)
    var positionProp = textLayer.property("Position");
    positionProp.setValueAtTime(startTime, [comp.width / 2, -100]);
    positionProp.setValueAtTime(startTime + 1, [comp.width / 2, comp.height / 2]);

    // Add easing
    var key1 = positionProp.keyTime(1);
    var key2 = positionProp.keyTime(2);

    positionProp.setTemporalEaseAtKey(2, [new KeyframeEase(0, 75)], [new KeyframeEase(0, 75)]);

    $.writeln("✅ Text animation created: " + config.text);

    return textLayer;
}

// Create transition
function createTransition(comp, config) {
    // TODO: Implement transitions
    $.writeln("ℹ️  Transition animation (placeholder)");
}

// Create text overlays
function createTextOverlays(comp, textOverlays) {
    $.writeln("📝 Creating " + textOverlays.length + " text overlays");

    for (var i = 0; i < textOverlays.length; i++) {
        createTextAnimation(comp, textOverlays[i]);
    }
}

// Apply color grading
function applyColorGrading(comp, colorPalette) {
    $.writeln("🎨 Applying color grading");

    // Create adjustment layer
    var adjLayer = comp.layers.addSolid(
        [1, 1, 1],
        "Color Grading",
        comp.width,
        comp.height,
        1.0
    );

    adjLayer.adjustmentLayer = true;

    // Add curves effect (basic color adjustment)
    try {
        var curves = adjLayer.Effects.addProperty("ADBE CurvesCustom");
        $.writeln("✅ Color grading applied");
    } catch (e) {
        $.writeln("⚠️  Could not apply curves effect");
    }
}

// Add to render queue
function addToRenderQueue(comp, outputPath) {
    $.writeln("🎬 Adding to render queue");

    var renderQueue = app.project.renderQueue;
    var renderItem = renderQueue.items.add(comp);

    // Configure output module
    var outputModule = renderItem.outputModule(1);

    if (outputPath) {
        outputModule.file = new File(outputPath);
    }

    // Set format to H.264 if available
    try {
        outputModule.applyTemplate("H.264");
    } catch (e) {
        $.writeln("⚠️  H.264 template not available, using default");
    }

    $.writeln("✅ Added to render queue: " + outputPath);

    return renderItem;
}

// Utility: Convert hex color to RGB
function hexToRgb(hex) {
    var result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
    return result ? [
        parseInt(result[1], 16) / 255,
        parseInt(result[2], 16) / 255,
        parseInt(result[3], 16) / 255
    ] : [1, 1, 1];
}

// Load config from JSON file and execute
function loadConfigAndExecute(configPath) {
    try {
        var configFile = new File(configPath);

        if (!configFile.exists) {
            throw new Error("Config file not found: " + configPath);
        }

        configFile.open("r");
        var configText = configFile.read();
        configFile.close();

        var config = eval("(" + configText + ")");

        return createSaaSVideo(config);

    } catch (e) {
        $.writeln("❌ Error loading config: " + e.toString());
        return {
            success: false,
            error: e.toString()
        };
    }
}

// Example usage (when run standalone):
// var result = loadConfigAndExecute("/path/to/config.json");
