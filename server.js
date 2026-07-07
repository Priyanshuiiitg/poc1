const express = require('express');
const multer = require('multer');
const { randomUUID } = require('crypto');
const { exec } = require('child_process');
const path = require('path');
const fs = require('fs');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.static('public')); // Serve the frontend

// Ensure uploads directory exists
const uploadsDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadsDir)) {
    fs.mkdirSync(uploadsDir);
}

// Multer setup for file uploads
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, 'uploads/')
    },
    filename: function (req, file, cb) {
        const uniqueSuffix = randomUUID() + path.extname(file.originalname);
        cb(null, file.fieldname + '-' + uniqueSuffix)
    }
});
const upload = multer({ storage: storage });

app.post('/api/convert', upload.single('document'), (req, res) => {
    if (!req.file) {
        return res.status(400).send({ error: 'No document uploaded.' });
    }

    const taskId = randomUUID();
    const inputFilePath = path.resolve(req.file.path);
    const outputPdfPath = path.resolve(uploadsDir, `${taskId}.pdf`);
    const xmlConfigPath = path.resolve(uploadsDir, `${taskId}.xml`);

    // Detect if we are on Windows (local dev) or Linux (edge device)
    const isWindows = process.platform === 'win32';
    const appRoot = path.resolve(__dirname);

    // The internal paths used by x2t
    const internalInput = isWindows ? `/app/uploads/${path.basename(inputFilePath)}` : inputFilePath;
    const internalOutput = isWindows ? `/app/uploads/${path.basename(outputPdfPath)}` : outputPdfPath;
    
    // For local Windows testing, we use the container's built-in fonts directly
    // For native Edge Linux, we use the extracted fonts
    const internalFontDir = isWindows ? `/var/www/euro-office/documentserver/core-fonts` : path.resolve(appRoot, 'x2t-engine/fonts/core-fonts');

    // Generate the required XML configuration for x2t
    const xmlContent = `<?xml version="1.0" encoding="utf-8"?>
<TaskQueueDataConvert>
    <m_sFileFrom>${internalInput}</m_sFileFrom>
    <m_sFileTo>${internalOutput}</m_sFileTo>
    <m_nFormatTo>513</m_nFormatTo>
    <m_bIsNoBase64>true</m_bIsNoBase64>
    <m_sFontDir>${internalFontDir}</m_sFontDir>
</TaskQueueDataConvert>`;

    fs.writeFileSync(xmlConfigPath, xmlContent);

    // Construct the command
    let command;
    if (isWindows) {
        // Run the engine via Docker Exec on Windows for local testing.
        // We use a persistent background daemon container (`euro-office-daemon`) that has already generated AllFonts.js.
        // This completely bypasses all Windows symlink and font extraction errors.
        command = `docker exec euro-office-daemon /bin/bash -c "export LD_LIBRARY_PATH=/var/www/euro-office/documentserver/server/FileConverter/bin:$LD_LIBRARY_PATH && /var/www/euro-office/documentserver/server/FileConverter/bin/x2t /app/uploads/${taskId}.xml"`;
    } else {
        // Run natively on the Linux edge device without Docker
        const engineBinPath = path.resolve(appRoot, 'x2t-engine/bin');
        command = `export LD_LIBRARY_PATH=${engineBinPath}:$LD_LIBRARY_PATH && ${engineBinPath}/x2t ${xmlConfigPath}`;
    }

    console.log(`Starting conversion for: ${req.file.originalname}`);
    
    exec(command, (error, stdout, stderr) => {
        // Cleanup XML configuration file
        try { fs.unlinkSync(xmlConfigPath); } catch (e) {}

        if (error) {
            console.error("x2t Error:", stderr);
            console.error("x2t Stdout:", stdout);
            return res.status(500).send({ error: "Document conversion failed." });
        }

        console.log(`Successfully converted to PDF: ${outputPdfPath}`);
        
        // Send the PDF back to the client
        res.sendFile(outputPdfPath, (err) => {
            // Cleanup the original Office document and the generated PDF after transmission
            try { fs.unlinkSync(inputFilePath); } catch (e) {}
            try { fs.unlinkSync(outputPdfPath); } catch (e) {}
        });
    });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Euro-Office Black Box Converter listening on port ${PORT}`);
    console.log(`Mode: ${process.platform === 'win32' ? 'Windows (Docker wrapper)' : 'Linux Native (Edge)'}`);
});
