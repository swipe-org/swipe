# swipe

##Abstract

This specification defines the features and syntax for Swipe, a mark-up language for describing interactive, media-rich and animated documents.

##Status of this document

This specification describes the current snapshot of the Swipe 0.1, which is still under development and may change drastically.

##1. Introduction

Swipe is a domain-specific, declarative language for non-developers (such as desiners, animators, illustrators, musicians, videographers and comic writers) to create interactive documents that contains photos, videos, vector graphics, animations, voices, musics and sound effects, which will be consumed on touch-enabled devices (such as smartphones, tablets and touch-enabled set-top-boxes). 

Since the introduction of iPhone, the capability of those mobile devices advanced significantly with faster CPU/GPU, a large amount memory and various sensors, but taking a full advantage of those capability is not easy.

While "Native programming" (such as in Objective-C, Swift, Java, and etc.) gives the best possible performance and the user experience, the development cost is very expensive, and supporting multiple devices is a nightmare.

Using a "cross-platform development environment", such as Unity, Coco3D, Corona and Flash has some advantages over native programming, but it still requires a "procedural programming", which only skilled developers are able to do. 

Building interactive applications on top of HTML browsers is now possible because of HTML5, but it still have many issues. Providing a good user experience is very difficult (this is why Facebook gave up this approach), and the development cost is as expensive as native or cross-platform development and still requires skilled developers.

People often debate over those three approaches, but they often overlook one important disadvantage of those three approaches. All those approaches require "procedural programming", which can be done only by skilled developers and are very expensive, error-prone and time-consuming. 

This disadvantage makes it economically impossible for those creative people to make quick prototypes and experimental works, just like an artist makes sketches with pencils and erasers.

Swipe was born to fill this gap. It allows non-developers to create interactive and media-rich documents without any help from developers. The declarative nature of Swift language (and the lack of "procedual programming environment") makes very easy to learn, write and read. It also makes it easy to auto-generate documents from data and create authoring environments.   
