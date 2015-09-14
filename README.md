# swipe

##Abstract

This specification defines the features and syntax for Swipe, a mark-up language for describing interactive, media-rich and animated documents.

##Status of this document

This specification describes the current snapshot of the Swipe 0.1, which is still under development and may change drastically.

##1. Introduction

Swipe is a domain-specific, declarative language for non-developers (such as designers, animators, illustrators, musicians, videographers and comic writers) to create interactive documents (books and presentations) that contains photos, videos, vector graphics, animations, voices, musics and sound effects, which will be consumed on touch-enabled devices (such as smartphones, tablets and touch-enabled set-top-boxes). 

Since the introduction of iPhone, the capability of those mobile devices advanced significantly with faster CPU/GPU, a large amount memory and various sensors, but taking a full advantage of those capability is not easy.

While "Native programming" (such as in Objective-C, Swift, Java, and etc.) gives the best possible performance and the user experience, the development cost is very expensive, and supporting multiple devices is a nightmare.

Using a "cross-platform development environment", such as Unity, Coco3D, Corona and Flash has some advantages over native programming, but it still requires a "procedural programming", which only skilled developers are able to do. 

Building interactive applications on top of HTML browsers became possible because of HTML5, but it still has many issues. Providing a good user experience is very difficult (this is why Facebook gave up this approach), and the development cost is as expensive as native or cross-platform development, requireing skilled developers.

People often debate over those three approaches, but they often overlook one important disadvantage of those three approaches. All those approaches require "procedural programming", which can be done only by skilled developers and are very expensive, error-prone and time-consuming. 

This disadvantage makes it very difficult for those creative people to make quick prototypes and experimental works, just like an artist makes sketches with pencils and erasers. It is economically impossible for individual creators to create interactive, media-rich books and publish them. 

Swipe was born to fill this gap. It allows non-developers to create interactive and media-rich documents without any help from developers. The declarative nature of Swipe language (and the lack of "procedual programming environment") makes very easy to learn, write and read. It also makes it easy to auto-generate documents (from data) and create authoring environments.   

##2. Document

A Swipe document is a UTF8 JSON file, which consists of a collection of pages. 

Here is a Swipe document which consists of two pages:

```
{
    "pages": [
        {
            "elements": [
                { "text":"Hello World!" }
            ]
        },
        {
            "elements": [
                { "text":"Good Bye!" }
            ]
        }
    ]
}
```
When the user opens this document with a Swipe viewer, the user will see only the first page with text "Hello World!" in the middle of screen. The user needs to swipe up (since the vertical scrolling is the default) to see the second page.

### Document Properties

- **title** (String): Title of the document, optional
- **bc** (Color): Background color, defalut is dark gray
- **dimension** ([Int, Int]): Dimension of the document, default is [320, 568]
- **paging** (String): Paging direction, *vertical* (default), *leftToRight* or *rightToLeft*
- **orientation** (String): Document orientation, *portrait* (default) or *landscape*
- **duration** (Float): Duration of the animation in seconds, default is 0.2 seconds
