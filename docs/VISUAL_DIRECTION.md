# Visual direction

Detailed side-view pixel art matching the approved Gandalf style. Slate-grey cloth, silver beard, warm wooden staff and blue-white magic. Vader target: black armor with cool highlights and red saber, but no character artwork was produced due to image-service blocks.

Runtime frame specification: 256x256 transparent cells, feet pivot (128,208), about112px standing height, nearest filtering. All Gandalf poses share a quantized palette. Physics and gameplay timing remain independent of sprite geometry and playback.

Source sequences are generated artwork, then deterministically segmented, aligned and packed. Invalid prop-disappearance poses are excluded and replaced by explicit holds. Walk/run are four-pose cycles; additional in-betweens and transition polish remain desirable.

Use docs/ART_INTEGRATION.md for the implementation contract and docs/art_validation.json for exact test coverage.
