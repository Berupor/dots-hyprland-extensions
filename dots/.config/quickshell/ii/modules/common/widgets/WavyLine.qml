import qs.modules.common
import QtQuick

Canvas {
    id: root
    property real amplitudeMultiplier: 0.5
    property real frequency: 6
    property color color: Appearance?.colors.colPrimary ?? "#685496"
    property real lineWidth: 4
    property real fullLength: width

    onPaint: {
        var ctx = getContext("2d");
        // Context2D only forwards lineWidth to the painter when the assigned value differs from
        // the one it already holds, so a single dropped command buffer (the canvas being resized
        // or reparented mid-paint) leaves the texture stroking with the default 1px pen for good.
        // Resetting first makes every frame re-send the whole pen state, thin line included.
        ctx.reset();

        var amplitude = root.lineWidth * root.amplitudeMultiplier;
        var frequency = root.frequency;
        var phase = Date.now() / 400.0;
        var centerY = height / 2;

        ctx.strokeStyle = root.color;
        ctx.lineWidth = root.lineWidth;
        ctx.lineCap = "round";
        ctx.beginPath();
        for (var x = ctx.lineWidth / 2; x <= root.width - ctx.lineWidth / 2; x += 1) {
            var waveY = centerY + amplitude * Math.sin(frequency * 2 * Math.PI * x / root.fullLength + phase);
            if (x === 0)
                ctx.moveTo(x, waveY);
            else
                ctx.lineTo(x, waveY);
        }
        ctx.stroke();
    }
}
