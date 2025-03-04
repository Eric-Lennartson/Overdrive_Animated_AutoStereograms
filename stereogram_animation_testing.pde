/* 
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>
*/

/*
 Issues:
 - width and height are difficult to deal with.
 it would be nice if I could just pass in an image
 and the program would just figure it out. 
*/
PGraphics canvas;
PImage img, photo, bg;
PrintWriter output;
PFont font;

final Boolean T = true;
final Boolean F = false;
final float HALF_ROOT_THREE = sqrt(3) * 0.5;

String title = "An_Untitled_Album_Featuring_Eric_David_Lennartson";

// Display Settings
Boolean show_magic = T; // magic eye or real image
Boolean show_letter = F; // letters instead of pixels
Boolean colored_text = F;
final int FONT_SIZE = 6;

// opacity and ratios
final float ratio = 90; // mixture of dark to light colors
final float PHOTO_OPACITY = 0.1;
final float PHOTO_SATURATION = 0.7;

// animation settings
Boolean animate = T;
Boolean grab_frame = T;
final int NUM_FRAMES = 1020;
final int FRAME_RATE = 17;

final int MAX_PATTERN_LENGTH = 2048; // maximum width of the image, also easy memory management
int[] pattern = new int[MAX_PATTERN_LENGTH];

// possible depths, setup inits the mapping from grayscale fill
// depth is inverted, 9 appears closest, 0 is furthest.
int[] depth = new int[7];

// NxN resolution of the magic eye
// higher sizes will be harder to calculate, but provide finer resolution
final int GRID_SIZE = 256; //256 for full size
int grid_step;
final int BG_GRID_SIZE = GRID_SIZE/2;
int bg_grid_step;

// length of the repeating pattern
final int pattern_length = GRID_SIZE/4;

color[] palette = {
// blue bonnet colors
#fee492, #cfd7ee, #446ced, #2463ef, #02117e,
#1d0540, #693974, #6a7e3c, #1c290c
};

// kludgey phasors
float t, t2;
float t_inc, t2_inc;
float mod1(float f) {
  return (f <= 1) ? f : f - floor(f);
}

float inc(float f, float amount) {
  return mod1(f + amount);
}

void setup()
{
  size(1080, 1080);
  grid_step = width / GRID_SIZE;
  bg_grid_step = width / BG_GRID_SIZE;
  canvas = createGraphics(width, height);

  font = createFont("IBMPlexMono-Bold.ttf", FONT_SIZE);
  textFont(font);

  output = createWriter("dmap.txt");

  //String s = "D:\\SoloWork\\EricLennartson\\2024\\AnUntitledAlbumFeaturingEricDavidLennartson\\ProcessingSketch";
  //String s2 = "D:\\SoloWork\\EricLennartson\\2024\\AnUntitledAlbumFeaturingEricDavidLennartson\\Images";
  photo = loadImage("./magic_eye_color_strip.png");
  photo.resize(width, height);
  bg = loadImage("./bb_top_edited.png");
  bg.resize(width, height);

  for (int i=0; i<depth.length; ++i)
  {
    depth[i] = (int)map(i, 0, depth.length-1, 50, 255);
  }

  t = 0;
  t2 = 0;
  t_inc = 1/340.0;
  t2_inc = 0.07/240.0;


  if (!animate) {
    noLoop();
  }
  frameRate(FRAME_RATE);
}


void draw() {
  background(255 * 0.18);

  //===========================================================================
  // Pixelized Background Image ===============================================
  //===========================================================================

  
  colorMode(HSB, 360, 100, 100);
  for (int y=0; y < height; y += bg_grid_step)
  {
    for (int x=0; x < width; x += bg_grid_step)
    {
      color c = bg.pixels[y*width+x];
      c = color(hue(c), saturation(c)*PHOTO_SATURATION, brightness(c)*PHOTO_OPACITY);
      noStroke();
      fill(c);
      rectMode(CORNER);
      square(x, y, bg_grid_step);
    }
  }
  colorMode(RGB, 255, 255, 255);

  //===========================================================================
  // Depth Map ================================================================
  //===========================================================================

  canvas.beginDraw();
  canvas.background(0);
  canvas.translate(width/2, height/2);

  // draw the flower tower (starting with 9 layers.
  float radius = width/2;
  int n_layers = 7;
  canvas.noStroke();
  for (int i=n_layers, d=0; i > 0; --i, d++)
  {
      canvas.fill(depth[d]);
      int n_petals = i+2;
      float angle = TWO_PI/n_petals;
      canvas.rotate(t2*TWO_PI);
      canvas.push();
      for (int j=0; j < n_petals; ++j)
      {
          PVector p1 = new PVector(radius, 0.0);
          PVector p2 = new PVector(cos(angle), sin(angle));
          float len = p1.dist(p2);
          canvas.triangle(0, -len/2,
                          0, len/2,
                          HALF_ROOT_THREE*len, 0);
          canvas.rotate(angle*t);
      }
      canvas.pop();
      radius *= Math.exp(-0.25);
  }
  canvas.endDraw();
  img = canvas.copy();

  //===========================================================================
  // Depth Map to Magic Eye ===================================================
  //===========================================================================

  if (show_magic)
  {
    img.loadPixels();
    loadPixels();

    int idx =0;
    for (int y=0; y < height; y += grid_step)
    {

      for (int x=0; x < width; x += grid_step)
      {
        // choose the color to display if there is no image to show
        float rnd = random(100);
        //int pixel = rnd > ratio ? palette[int(random(palette.length))] : #222222;
        int pixel = rnd > ratio ? photo.pixels[y*width+x] : #000000;
        //int letter = floor(random(32)) + 'A';
        //int letter = title.charAt(floor(random(title.length())));
        int letter = title.charAt(idx);
        idx = (idx+1)%title.length();

        // calculate the depth as an offset
        int depth = 0;
        if (x > pattern_length)
        {
          float b = brightness(img.pixels[x*width+y]);
          //output.print(b > 200 ? '1' : '0');

          depth = floor(map(b, 0, 255, 0, -9));
          //depth = b > 200 ? -1 : 0;
        } else
        {
          output.print('0');
          depth = 0;
        }

        // now we're treating depth as an index
        depth += pattern_length; // move to the end of the pattern
        depth = (x/grid_step) - depth; // subtract that from our current position

        // now we want to make it a color
        if (depth < 0) { // only called when we skip
          depth = show_letter ? letter : pixel;
        } else {
          depth = pattern[depth];
        }

        pattern[(x/grid_step)] = depth;

        if (show_letter) {
          fill(pixel);
          //fill(colored_text ? pixel : 255*0.18, 255*0.8);
          char ch = (char)depth;
          rnd = random(100);
          if(rnd > ratio)
            text(ch, x+(grid_step/4), y+grid_step);
          //output.print((char)depth);
        } else {
          color c = color(depth, 255);
          if (brightness(c) > 1) { // ignore black pixels

            //colorMode(HSB, 360, 100, 100);
            //c = color(hue(c), saturation(c)*1.1, brightness(c)*1.1);
            //colorMode(RGB, 255, 255, 255);
            fill(c);

            strokeWeight(1);
            stroke(255*0.18, 80);
            rectMode(CORNER);
            square(x, y, grid_step);
          }
        }
      }
      output.println();
    }

    output.flush(); // not necessary?
    output.close();
  } else {
    image(img, 0, 0);
  }

  // frameCount starts from 1
  if (grab_frame && frameCount <= NUM_FRAMES) {
    saveFrame("./frames/magic/####.png");
  }

  if(t < 1)
    t += t_inc;
  t2 = inc(t2, t2_inc);
}
